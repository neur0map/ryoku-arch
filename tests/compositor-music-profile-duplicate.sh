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

niri="shell/modules/settings/NiriConfig.qml"
extras="shell/modules/settings/ExtrasConfig.qml"
profile="install/profiles/music-rmpc/profile"
launcher="shell/services/AppLauncher.qml"

assert_not_contains "$niri" "Music Player (rmpc)"
assert_not_contains "$niri" "Open Extras to install"
assert_not_contains "$niri" "ryoku-music-daemon-set"
assert_not_contains "$niri" "ryoku-mpd-set-music-dir"
assert_not_contains "$niri" "_rmpcProbe"
assert_not_contains "$niri" "_musicDirDialog"

assert_contains "$extras" "ryoku-cmd-profile-list"
assert_contains "$profile" "PROFILE_NAME=\"Music (rmpc + MPD)\""
assert_contains "$launcher" "Music (rmpc + MPD) profile from Extras"

echo "PASS: compositor music profile duplicate removed"
