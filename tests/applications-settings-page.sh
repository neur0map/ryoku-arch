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

  grep -qF -- "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"

  ! grep -qF -- "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

settings="shell/modules/settings/SettingsOverlay.qml"
services="shell/modules/settings/ServicesConfig.qml"
apps="shell/modules/settings/ApplicationsConfig.qml"

[[ -f $ROOT_DIR/$apps ]] || fail "missing $apps"

assert_contains "$apps" "settingsPageIndex: 16"
assert_contains "$apps" "settingsPageName: Translation.tr(\"Applications\")"
assert_contains "$apps" "ryokuBinPath"
assert_contains "$apps" "RYOKU_PATH"
assert_contains "$apps" "ryoku-music-daemon-set"
assert_contains "$apps" "ryoku-mpd-set-music-dir"
assert_contains "$apps" "GlobalStates.settingsOverlayRequestedPage = 15"
assert_contains "$apps" "Music Player (rmpc)"
assert_contains "$settings" "pages: [1, 7, 8, 15, 16]"
assert_contains "$settings" "modules/settings/ApplicationsConfig.qml"
assert_contains "$settings" "onSettingsOverlayRequestedPageChanged"
assert_not_contains "$services" "Music Player (rmpc)"
assert_not_contains "$services" "ryoku-music-daemon-set"

echo "PASS: applications settings page"
