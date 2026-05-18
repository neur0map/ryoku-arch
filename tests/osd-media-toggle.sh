#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  assert_file "$path"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  assert_file "$path"
  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

assert_json_expr "shell/defaults/config.json" '.osd.mediaEnabled == true' \
  "shell defaults should enable media OSD feedback"

assert_contains "shell/modules/common/Config.qml" "property bool mediaEnabled: true"

assert_contains "shell/modules/settings/ToolsConfig.qml" 'text: Translation.tr("Media OSD")'
assert_contains "shell/modules/settings/ToolsConfig.qml" 'Config.setNestedValue("osd.mediaEnabled", checked);'

assert_contains "shell/modules/onScreenDisplay/OnScreenDisplay.qml" \
  "readonly property bool osdActive: GlobalStates.osdVolumeOpen || GlobalStates.osdBrightnessOpen || GlobalStates.osdMediaOpen || GlobalStates.osdKeyboardLayoutOpen"
assert_contains "shell/modules/onScreenDisplay/OnScreenDisplay.qml" \
  "function setOpenStates(volume, brightness, media, keyboardLayout)"
assert_contains "shell/modules/onScreenDisplay/OnScreenDisplay.qml" \
  "GlobalStates.osdBrightnessOpen = brightness;"
assert_contains "shell/modules/onScreenDisplay/OnScreenDisplay.qml" \
  "GlobalStates.osdKeyboardLayoutOpen = keyboardLayout;"
assert_contains "shell/modules/onScreenDisplay/OnScreenDisplay.qml" \
  "if (!(Config.options?.osd?.mediaEnabled ?? true)) return;"
assert_contains "shell/modules/onScreenDisplay/OnScreenDisplay.qml" \
  "function onOsdMediaOpenChanged()"
assert_contains "shell/services/MprisController.qml" \
  "if (Config.options?.osd?.mediaEnabled ?? true)"

echo "ok: osd media toggle static asserts"
