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

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"

  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
  ! grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

assert_contains "config/niri/config.d/40-environment.kdl" 'QT_QPA_PLATFORM "wayland;xcb"'
assert_not_contains "config/niri/config.d/40-environment.kdl" 'QT_QPA_PLATFORM "wayland"'

assert_contains "shell/defaults/niri/config.d/40-environment.kdl" 'QT_QPA_PLATFORM "wayland;xcb"'
assert_not_contains "shell/defaults/niri/config.d/40-environment.kdl" 'QT_QPA_PLATFORM "wayland"'

assert_contains "shell/scripts/ryoku-shell" 'QT_QPA_PLATFORM=wayland;xcb'
assert_not_contains "shell/scripts/ryoku-shell" 'QT_QPA_PLATFORM=wayland")'
assert_contains "shell/sdata/lib/package-installers.sh" 'QT_QPA_PLATFORM=wayland;xcb'

assert_contains "config/systemd/user/ryoku-shell.service.d/qt6-fractional-scale-workaround.conf" 'QT_WAYLAND_DISABLE_FRACTIONAL_SCALE=1'
assert_contains "config/systemd/user/ryoku-shell.service.d/qt6-fractional-scale-workaround.conf" 'QT_SCALE_FACTOR_ROUNDING_POLICY=Round'

assert_contains "migrations/1778634987.sh" 'QT_QPA_PLATFORM "wayland;xcb"'
assert_contains "migrations/1778634987.sh" 'QT_QPA_PLATFORM=wayland;xcb'
assert_contains "migrations/1778634987.sh" 'set-environment QT_QPA_PLATFORM="$QT_QPA_PLATFORM"'

echo "ok: niri-qt-platform-fallback static asserts"
