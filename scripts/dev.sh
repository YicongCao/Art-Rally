#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="$(sed -n 's/^config\/version="\([^"]*\)"/\1/p' "$ROOT/project.godot")"
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
  run_external_logged "$log" "$ENGINE" "$@"
}

run_external_logged() {
  local log="$1"
  shift
  "$@" 2>&1 | tee "$log"
  # Godot may exit successfully despite a resource or GDScript load error.
  if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:|Parse Error:' "$log"; then
    echo "Godot reported an error. See $log" >&2
    return 1
  fi
}

prepare_runtime() {
  mkdir -p "$ROOT/logs"
  # A source checkout has no imported assets or global GDScript class cache.
  # Refresh both before running, including after pulling new scripts/assets.
  printf 'Preparing Brushline Rally project: %s\n' "$ROOT"
  if command -v git >/dev/null 2>&1 && git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf 'Source revision: %s (%s)\n' "$(git -C "$ROOT" rev-parse --short HEAD)" "$(git -C "$ROOT" branch --show-current)"
  fi
  run_logged "$ROOT/logs/startup_import.log" --headless --path "$ROOT" --editor --import
}

MODE="${1:-editor}"
if [[ $# -gt 0 ]]; then shift; fi
case "$MODE" in
  screenprint-export)
    BLENDER_EXEC="${BLENDER_BIN:-/Applications/Blender.app/Contents/MacOS/Blender}"
    if [[ ! -x "$BLENDER_EXEC" ]]; then BLENDER_EXEC="$(command -v blender || true)"; fi
    if [[ -z "$BLENDER_EXEC" ]]; then echo "Set BLENDER_BIN to your Blender executable." >&2; exit 1; fi
    mkdir -p "$ROOT/logs"
    run_external_logged "$ROOT/logs/screenprint_export.log" "$BLENDER_EXEC" --background --python "$ROOT/scripts/export_screenprint.py" -- "$@"
    grep -q '^SCREENPRINT EXPORT PASSED' "$ROOT/logs/screenprint_export.log"
    prepare_runtime
    ;;
  screenprint-check)
    prepare_runtime
    run_logged "$ROOT/logs/screenprint_test.log" --headless --path "$ROOT" --script res://tests/screenprint_test.gd
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/screenprint_test.log"
    ;;
  screenprint-capture)
    prepare_runtime
    run_logged "$ROOT/logs/screenprint_capture.log" --path "$ROOT" --max-fps 60 --script res://scripts/dev/screenprint_capture.gd -- --test-defaults "$@"
    ;;
  first-playable-matrix|first-playable-lifecycle|first-playable-audio|first-playable-capture|first-playable-perf)
    mkdir -p "$ROOT/logs"
    case "$MODE" in
      first-playable-matrix) run_logged "$ROOT/logs/first_playable_matrix.log" --headless --path "$ROOT" --fixed-fps 120 --script res://tests/first_playable_matrix.gd -- --test-defaults ;;
      first-playable-lifecycle) run_logged "$ROOT/logs/first_playable_lifecycle.log" --headless --path "$ROOT" --script res://tests/first_playable_lifecycle.gd -- --test-defaults ;;
      first-playable-audio) run_logged "$ROOT/logs/first_playable_audio.log" --path "$ROOT" --script res://tests/first_playable_audio_check.gd -- --test-defaults ;;
      first-playable-capture) run_logged "$ROOT/logs/first_playable_capture.log" --path "$ROOT" --script res://scripts/dev/first_playable_capture.gd -- --test-defaults ;;
      first-playable-perf) run_logged "$ROOT/logs/first_playable_performance.log" --path "$ROOT" --fixed-fps 60 --script res://tests/first_playable_perf.gd -- --test-defaults ;;
    esac
    ;;
  doctor)
    TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/$EXPECTED.stable"
    MACOS_TEMPLATE_STATUS="missing"
    WINDOWS_TEMPLATE_STATUS="missing"
    [[ -f "$TEMPLATE_DIR/macos.zip" ]] && MACOS_TEMPLATE_STATUS="$TEMPLATE_DIR/macos.zip"
    [[ -f "$TEMPLATE_DIR/windows_release_x86_64.exe" ]] && WINDOWS_TEMPLATE_STATUS="$TEMPLATE_DIR/windows_release_x86_64.exe"
    printf 'Engine: %s\nVersion: %s\nProject: %s\nArchitecture: %s\nmacOS template: %s\nWindows x86_64 template: %s\n' "$ENGINE" "$ACTUAL" "$ROOT" "$(uname -m)" "$MACOS_TEMPLATE_STATUS" "$WINDOWS_TEMPLATE_STATUS"
    ;;
  editor)
    exec "$ENGINE" --path "$ROOT" --editor "$@"
    ;;
  run)
    prepare_runtime
    run_logged "$ROOT/logs/game.log" --path "$ROOT" "$@"
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
      if [[ "$(basename "$test")" == "flag_render_test.gd" ]]; then
        run_logged "$ROOT/logs/$(basename "$test" .gd).log" --path "$ROOT" --max-fps 60 --script "$test"
      else
        run_logged "$ROOT/logs/$(basename "$test" .gd).log" --headless --path "$ROOT" --fixed-fps 120 --script "$test"
      fi
      grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/$(basename "$test" .gd).log"
    done
    python3 "$ROOT/tests/calibrate_medals_test.py"
    python3 "$ROOT/tests/music_score_test.py"
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
    prepare_runtime
    exec "$ENGINE" --path "$ROOT" --scene res://scenes/dev/driving_lab.tscn "$@"
    ;;
  stage)
    prepare_runtime
    exec "$ENGINE" --path "$ROOT" --scene res://scenes/stages/sunset_ridge.tscn "$@"
    ;;
  preview)
    prepare_runtime
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
  m6-perf)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/m6_performance.log" --path "$ROOT" --always-on-top --disable-vsync --max-fps 0 --script res://tests/m6_performance_check.gd -- --test-defaults "$@"
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/m6_performance.log"
    ;;
  m6-release-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/m6_release_check.log" --path "$ROOT" --max-fps 60 --script res://tests/m6_release_check.gd -- --test-defaults
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/m6_release_check.log"
    ;;
  v02-tire-render-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/tire_feedback_render_check.log" --path "$ROOT" --max-fps 60 --script res://tests/tire_feedback_render_check.gd -- --test-defaults
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/tire_feedback_render_check.log"
    ;;
  pacenote-render-check)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/pacenote_render_check.log" --path "$ROOT" --max-fps 60 --script res://tests/pacenote_render_check.gd
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/pacenote_render_check.log"
    ;;
  autumn-capture)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/autumn_capture.log" --path "$ROOT" --max-fps 60 --script res://tests/autumn_capture.gd -- --test-defaults
    grep -q '^TEST RESULT: .* 0 failures$' "$ROOT/logs/autumn_capture.log"
    ;;
  controller-probe)
    mkdir -p "$ROOT/logs"
    run_logged "$ROOT/logs/controller_probe.log" --path "$ROOT" --max-fps 60 --script res://tests/controller_probe.gd
    grep -q '^CONTROLLER PROBE:' "$ROOT/logs/controller_probe.log"
    ;;
  export-macos)
    TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/$EXPECTED.stable"
    if [[ ! -f "$TEMPLATE_DIR/macos.zip" ]]; then
      echo "Missing matching macOS export template: $TEMPLATE_DIR/macos.zip" >&2
      exit 1
    fi
    mkdir -p "$ROOT/logs" "$ROOT/builds/macos"
    rm -rf "$ROOT/builds/macos/Brushline Rally.app" "$ROOT/builds/macos/Brushline-Rally-${VERSION}-macos-universal.zip"
    run_logged "$ROOT/logs/export_macos.log" --headless --path "$ROOT" --export-release "macOS" "$ROOT/builds/macos/Brushline Rally.app"
    test -x "$ROOT/builds/macos/Brushline Rally.app/Contents/MacOS/Brushline Rally"
    cp "$ROOT/docs/PLAY_GUIDE.zh-CN.md" "$ROOT/docs/ASSET_CREDITS.md" "$ROOT/assets/licenses/Godot-LICENSE.txt" "$ROOT/assets/licenses/Godot-THIRD-PARTY.json" "$ROOT/builds/macos/"
    ditto -c -k --sequesterRsrc --keepParent "$ROOT/builds/macos/Brushline Rally.app" "$ROOT/builds/macos/Brushline-Rally-${VERSION}-macos-universal.zip"
    (cd "$ROOT/builds/macos" && /usr/bin/zip -q "Brushline-Rally-${VERSION}-macos-universal.zip" PLAY_GUIDE.zh-CN.md ASSET_CREDITS.md Godot-LICENSE.txt Godot-THIRD-PARTY.json)
    (cd "$ROOT/builds/macos" && shasum -a 256 "Brushline-Rally-${VERSION}-macos-universal.zip" > "Brushline-Rally-${VERSION}-macos-universal.zip.sha256")
    ;;
  macos-app-check)
    APP="$ROOT/builds/macos/Brushline Rally.app"
    EXECUTABLE="$APP/Contents/MacOS/Brushline Rally"
    test -x "$EXECUTABLE"
    mkdir -p "$ROOT/logs"
    run_external_logged "$ROOT/logs/macos_app_check.log" "$EXECUTABLE" --max-fps 60 -- --test-defaults --package-smoke
    grep -q '^PACKAGE SMOKE PASSED$' "$ROOT/logs/macos_app_check.log"
    test "$(plutil -extract CFBundleIdentifier raw "$APP/Contents/Info.plist")" = "com.yicongcao.brushlinerally"
    lipo -archs "$EXECUTABLE" | grep -qw arm64
    ;;
  export-windows)
    TEMPLATE_DIR="$HOME/Library/Application Support/Godot/export_templates/$EXPECTED.stable"
    if [[ ! -f "$TEMPLATE_DIR/windows_release_x86_64.exe" ]]; then
      echo "Missing matching Windows x86_64 export template: $TEMPLATE_DIR/windows_release_x86_64.exe" >&2
      exit 1
    fi
    mkdir -p "$ROOT/logs" "$ROOT/builds/windows"
    rm -rf "$ROOT/builds/windows/Brushline Rally" "$ROOT/builds/windows/Brushline-Rally-${VERSION}-windows-x86_64.zip" "$ROOT/builds/windows/Brushline-Rally-${VERSION}-windows-x86_64.zip.sha256"
    mkdir -p "$ROOT/builds/windows/Brushline Rally"
    run_logged "$ROOT/logs/export_windows.log" --headless --path "$ROOT" --export-release "Windows Desktop" "$ROOT/builds/windows/Brushline Rally/Brushline Rally.exe"
    test -f "$ROOT/builds/windows/Brushline Rally/Brushline Rally.exe"
    cp "$ROOT/docs/PLAY_GUIDE.zh-CN.md" "$ROOT/docs/ASSET_CREDITS.md" "$ROOT/assets/licenses/Godot-LICENSE.txt" "$ROOT/assets/licenses/Godot-THIRD-PARTY.json" "$ROOT/builds/windows/Brushline Rally/"
    (cd "$ROOT/builds/windows" && /usr/bin/zip -r -9 -X "Brushline-Rally-${VERSION}-windows-x86_64.zip" "Brushline Rally")
    (cd "$ROOT/builds/windows" && shasum -a 256 "Brushline-Rally-${VERSION}-windows-x86_64.zip" > "Brushline-Rally-${VERSION}-windows-x86_64.zip.sha256")
    ;;
  windows-package-check)
    EXE="$ROOT/builds/windows/Brushline Rally/Brushline Rally.exe"
    ZIP="$ROOT/builds/windows/Brushline-Rally-${VERSION}-windows-x86_64.zip"
    test -f "$EXE" -a -f "$ZIP"
    file "$EXE" | grep -Eq 'PE32\+ executable.*x86-64'
    python3 - "$EXE" <<'PY'
import pathlib, struct, sys
path = pathlib.Path(sys.argv[1])
data = path.read_bytes()
assert data[:2] == b"MZ"
pe = struct.unpack_from("<I", data, 0x3C)[0]
assert data[pe:pe + 4] == b"PE\0\0"
assert struct.unpack_from("<H", data, pe + 4)[0] == 0x8664
assert struct.unpack_from("<H", data, pe + 24)[0] == 0x20B
assert len(data) > 120_000_000
print("WINDOWS PACKAGE STRUCTURE PASSED")
PY
    unzip -t "$ZIP" >/dev/null
    grep -q 'res://scripts/dev/package_smoke.gd.remap' "$ROOT/logs/export_windows.log"
    ;;
  *)
    echo "Usage: $0 {doctor|editor|run|lab|stage|preview|check|regression|stage-check|stage-matrix|preview-check|preview-render-check|m5-render-check|drive-choice-render-check|autopilot-render-check|result-render-check|m6-perf|m6-release-check|v02-tire-render-check|pacenote-render-check|autumn-capture|controller-probe|export-macos|macos-app-check|export-windows|windows-package-check} [Godot options]" >&2
    exit 2
    ;;
esac
