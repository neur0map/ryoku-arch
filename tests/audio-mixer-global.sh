#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="install/config/hardware/fix-audio-mixer.sh"
HELPER="bin/ryoku-audio-restore-mixers"
SOFT_MIXER_CONFIG="default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf"
MIGRATION="migrations/1777827891.sh"
BASS_MIGRATION="migrations/1779493500.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  if grep -Eq "$pattern" "$ROOT_DIR/$path"; then
    fail "$message"
  fi
}

assert_contains "$SCRIPT" 'alsa-soft-mixer\.conf' \
  "Global audio mixer fix should install WirePlumber ALSA soft-mixer config"
assert_contains "$SOFT_MIXER_CONFIG" 'api\.alsa\.soft-mixer = true' \
  "Global audio mixer fix should install WirePlumber ALSA soft-mixer config"
# shellcheck disable=SC2016
assert_contains "$SCRIPT" '\$RYOKU_PATH/bin/ryoku-audio-restore-mixers' \
  "Global audio mixer fix should delegate hardware output initialization to the shared helper"
# shellcheck disable=SC2016
assert_contains "$HELPER" 'set "\$ctl" 100% unmute' \
  "Shared audio mixer helper should initialize hardware outputs at 100%"
assert_contains "$HELPER" '"Bass Speaker"' \
  "Shared audio mixer helper should initialize laptop bass speaker switches"
# shellcheck disable=SC2016
assert_not_contains "$SCRIPT" 'set "\$ctl" 80% unmute|set Master 80% unmute' \
  "Global audio mixer fix should not leave hardware outputs attenuated"
assert_contains "$MIGRATION" 'install/config/hardware/fix-audio-mixer\.sh' \
  "Hardware volume migration should source the current global mixer fix"
assert_contains "$BASS_MIGRATION" 'install/config/hardware/fix-audio-mixer\.sh' \
  "Bass speaker migration should source the current global mixer fix"
assert_not_contains "$MIGRATION" 'install/config/hardware/asus/fix-audio-mixer\.sh|ryoku-restart-pipewire|systemctl --user restart pipewire' \
  "Hardware volume migration should not use the old ASUS-only mixer path or reset PipeWire volume"
assert_not_contains "$BASS_MIGRATION" 'ryoku-restart-pipewire|systemctl --user restart pipewire' \
  "Bass speaker migration should not reset PipeWire volume"
assert_not_contains "migrations/1768916735.sh" 'install/config/hardware/asus/fix-audio-mixer\.sh|ryoku-restart-pipewire|systemctl --user restart pipewire' \
  "Older migration should not use the old ASUS-only mixer path or reset PipeWire volume"

echo "PASS: global audio mixer"
