#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="install/config/hardware/fix-audio-mixer.sh"
SOFT_MIXER_CONFIG="default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf"
MIGRATION="migrations/1777827891.sh"

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
assert_contains "$SCRIPT" 'set "\$ctl" 100% unmute' \
  "Global audio mixer fix should initialize hardware outputs at 100%"
# shellcheck disable=SC2016
assert_not_contains "$SCRIPT" 'set "\$ctl" 80% unmute|set Master 80% unmute' \
  "Global audio mixer fix should not leave hardware outputs attenuated"
assert_contains "$MIGRATION" 'install/config/hardware/fix-audio-mixer\.sh' \
  "Hardware volume migration should source the current global mixer fix"
assert_not_contains "$MIGRATION" 'install/config/hardware/asus/fix-audio-mixer\.sh|ryoku-restart-pipewire|systemctl --user restart pipewire' \
  "Hardware volume migration should not use the old ASUS-only mixer path or reset PipeWire volume"
assert_not_contains "migrations/1768916735.sh" 'install/config/hardware/asus/fix-audio-mixer\.sh|ryoku-restart-pipewire|systemctl --user restart pipewire' \
  "Older migration should not use the old ASUS-only mixer path or reset PipeWire volume"

echo "PASS: global audio mixer"
