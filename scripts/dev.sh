#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED="$(tr -d '\r\n' < "$ROOT/.godot-version")"

if [[ -n "${GODOT_BIN:-}" ]]; then
  ENGINE="$GODOT_BIN"
elif command -v godot >/dev/null 2>&1; then
  ENGINE="$(command -v godot)"
elif [[ -x /Applications/Godot.app/Contents/MacOS/Godot ]]; then
  ENGINE=/Applications/Godot.app/Contents/MacOS/Godot
else
  echo "Godot not found. On macOS: brew install --cask godot" >&2
  echo "For a versioned/custom installation, set GODOT_BIN to its executable." >&2
  exit 1
fi

ACTUAL="$("$ENGINE" --version)"
if [[ "$ACTUAL" != "$EXPECTED".* ]]; then
  echo "Expected Godot $EXPECTED, found $ACTUAL. Use GODOT_BIN or explicitly update the version lock." >&2
  exit 1
fi

run_logged() {
  local log="$1"
  shift
  "$ENGINE" "$@" 2>&1 | tee "$log"
  # Godot may exit successfully despite a resource or GDScript load error.
  if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:' "$log"; then
    echo "Godot reported an error. See $log" >&2
    return 1
  fi
}

MODE="${1:-editor}"
if [[ $# -gt 0 ]]; then shift; fi
case "$MODE" in
  doctor)
    printf 'Engine: %s\nVersion: %s\nProject: %s\nArchitecture: %s\n' "$ENGINE" "$ACTUAL" "$ROOT" "$(uname -m)"
    ;;
  editor)
    exec "$ENGINE" --path "$ROOT" --editor "$@"
    ;;
  run)
    exec "$ENGINE" --path "$ROOT" "$@"
    ;;
  check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/import.log" --headless --path "$ROOT" --editor --import
    while IFS= read -r script; do
      run_logged "$ROOT/logs/parse.log" --headless --path "$ROOT" --check-only --script "$script"
    done < <(find "$ROOT/scripts" "$ROOT/tests" -name '*.gd' -type f | sort)
    run_logged "$ROOT/logs/smoke.log" --headless --path "$ROOT" --script res://tests/smoke_test.gd
    grep -q '^SMOKE TEST PASSED$' "$ROOT/logs/smoke.log"
    for test in "$ROOT"/tests/*_test.gd; do
      [[ "$(basename "$test")" == "smoke_test.gd" ]] && continue
      run_logged "$ROOT/logs/$(basename "$test" .gd).log" --headless --path "$ROOT" --fixed-fps 120 --script "$test"
      grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/$(basename "$test" .gd).log"
    done
    ;;
  regression)
    "$ROOT/scripts/dev.sh" check
    python3 "$ROOT/scripts/frame_rate_check.py" "$ENGINE" "$ROOT"
    ;;
  stage-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/stage_drive.log" --headless --path "$ROOT" --fixed-fps 120 --script res://tests/stage_drive.gd -- "$@"
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/stage_drive.log"
    ;;
  stage-matrix)
    mkdir -p "$ROOT/logs"
    for layout in FWD AWD RWD; do
      for input in vkeyboard vgamepad; do
        log="$ROOT/logs/stage_drive_${layout}_${input}.log"
        run_logged "$log" --headless --path "$ROOT" --fixed-fps 120 --script res://tests/stage_drive.gd -- "--layout=$layout" "--input=$input"
        grep -q '^TEST RESULT: .* 0 failures$' "$log"
      done
    done
    ;;
  lab)
    exec "$ENGINE" --path "$ROOT" --scene res://scenes/dev/driving_lab.tscn "$@"
    ;;
  stage)
    exec "$ENGINE" --path "$ROOT" --scene res://scenes/stages/sunset_ridge.tscn "$@"
    ;;
  preview)
    exec "$ENGINE" --path "$ROOT" --scene res://scenes/dev/visual_sample.tscn "$@"
    ;;
  preview-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/preview_drive.log" --headless --path "$ROOT" --fixed-fps 120 --script res://tests/preview_drive.gd
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/preview_drive.log"
    ;;
  preview-render-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/flare_render_check.log" --path "$ROOT" --max-fps 60 --script res://tests/flare_render_check.gd
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/flare_render_check.log"
    ;;
  m5-render-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/m5_render_check.log" --path "$ROOT" --max-fps 60 --script res://tests/m5_render_check.gd -- --test-defaults
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/m5_render_check.log"
    ;;
  drive-choice-render-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/drive_choice_render_check.log" --path "$ROOT" --max-fps 60 --script res://tests/drive_choice_render_check.gd -- --test-defaults
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/drive_choice_render_check.log"
    ;;
  autopilot-render-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/autopilot_render_check.log" --path "$ROOT" --max-fps 60 --script res://tests/autopilot_render_check.gd -- --test-defaults
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/autopilot_render_check.log"
    ;;
  result-render-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/result_render_check.log" --path "$ROOT" --max-fps 60 --script res://tests/result_render_check.gd -- --test-defaults
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/result_render_check.log"
    ;;
  *)
    echo "Usage: $0 {doctor|editor|run|lab|stage|preview|check|regression|stage-check|stage-matrix|preview-check|preview-render-check|m5-render-check|drive-choice-render-check|autopilot-render-check|result-render-check} [Godot options]" >&2
    exit 2
    ;;
esac
