#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="install/config/hardware/asus/fix-audio-mixer.sh"
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
  "ASUS audio mixer fix should install WirePlumber ALSA soft-mixer config"
assert_contains "$SOFT_MIXER_CONFIG" 'api\.alsa\.soft-mixer = true' \
  "ASUS audio mixer fix should install WirePlumber ALSA soft-mixer config"
assert_contains "$SCRIPT" 'set Master 100% unmute' \
  "ASUS audio mixer fix should initialize the hardware Master output at 100%"
assert_not_contains "$SCRIPT" 'set Master 80% unmute' \
  "ASUS audio mixer fix should not leave the hardware Master output attenuated"
assert_not_contains "$MIGRATION" 'ryoku-restart-pipewire|systemctl --user restart pipewire' \
  "ASUS hardware volume migration should not reset the user's PipeWire volume"

echo "PASS: asus audio mixer"
