#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

assert_json_value() {
  local query="$1"
  local expected="$2"
  local actual

  actual="$(jq -r "$query" "$ROOT_DIR/shell/defaults/config.json")"
  [[ $actual == "$expected" ]] || fail "$query should be $expected, got $actual"
}

recorder="shell/modules/ii/overlay/recorder/Recorder.qml"
config="shell/modules/common/Config.qml"

assert_json_value ".overlay.recorder.autoHideOnFullscreen" "true"
assert_json_value ".overlay.recorder.suppressToasts" "true"
assert_json_value ".overlay.recorder.disableNiriAnims" "false"

assert_contains "$config" "property JsonObject recorder: JsonObject"
assert_contains "$config" "property bool autoHideOnFullscreen: true"
assert_contains "$config" "property bool suppressToasts: true"
assert_contains "$config" "property bool disableNiriAnims: false"

assert_contains "shell/services/RecorderStatus.qml" "property int elapsedSeconds"
assert_contains "shell/services/RecorderStatus.qml" "recordingStartTime"
assert_contains "shell/services/RecorderStatus.qml" "elapsedTimer"

assert_contains "$recorder" "title: RecorderStatus.isRecording"
assert_contains "$recorder" "formatElapsed(RecorderStatus.elapsedSeconds)"
assert_contains "$recorder" "function formatElapsed(totalSec: int): string"
assert_contains "$recorder" "property string _diskFreeText"
assert_contains "$recorder" "id: diskQueryProcess"
assert_contains "$recorder" "df -BG --output=avail"
assert_contains "$recorder" "RecorderStatusBar"
assert_contains "$recorder" "RecorderGameModeSection"
assert_contains "$recorder" "GameModeToggle"
assert_contains "$recorder" "Game Mode Overrides"
assert_contains "$recorder" "overlay.recorder.autoHideOnFullscreen"
assert_contains "$recorder" "overlay.recorder.suppressToasts"
assert_contains "$recorder" "overlay.recorder.disableNiriAnims"
assert_contains "$recorder" "Config.setNestedValue(gmToggle.configKey"
assert_contains "$recorder" "visible: RecorderStatus.isRecording"
assert_contains "$recorder" "Quickshell.shellPath(\"scripts/ryoku-shell\")"
old_script_ref="scripts/i""nir"
assert_not_contains "$recorder" "$old_script_ref"

echo "PASS: recorder widget redesign"
