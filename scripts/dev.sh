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
    run_logged "$ROOT/logs/stage_drive.log" --headless --path "$ROOT" --fixed-fps 120 --script res://tests/stage_drive.gd
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/stage_drive.log"
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
  *)
    echo "Usage: $0 {doctor|editor|run|lab|stage|preview|check|regression|stage-check} [Godot options]" >&2
    exit 2
    ;;
esac
