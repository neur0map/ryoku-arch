#!/bin/bash

set -euo pipefail

# Regression guard for the "100% volume but barely audible" symptom.
#
# Forcing WirePlumber software mixing (api.alsa.soft-mixer = true) decoupled the
# volume slider from the codec's hardware "Master", so any device whose hardware
# Master shipped attenuated played ~20dB down - on laptop speakers, headphones,
# and external/USB outputs alike. The fix is hardware-agnostic: never force soft
# mixing, let WirePlumber manage the hardware mixer natively (the slider drives
# the hardware Master), and keep only the universal WirePlumber 40%
# default-sink-volume override.

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="install/config/hardware/fix-audio-mixer.sh"
HELPER="bin/ryoku-audio-restore-mixers"
SOFT_MIXER_CONFIG="default/wireplumber/wireplumber.conf.d/alsa-soft-mixer.conf"
MIGRATION="migrations/1780686214.sh"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  grep -Eq "$2" "$ROOT_DIR/$1" || fail "$3"
}

assert_not_contains() {
  if grep -Eq "$2" "$ROOT_DIR/$1"; then
    fail "$3"
  fi
}

# 1. The soft-mixer override must not be forced anywhere - it is the cause of the
#    dimmed audio, not the fix.
if [[ -e $ROOT_DIR/$SOFT_MIXER_CONFIG ]]; then
  fail "soft-mixer override ($SOFT_MIXER_CONFIG) must be removed - forcing it dimmed audio"
fi
assert_not_contains "$SCRIPT" 'api\.alsa\.soft-mixer' \
  "fix-audio-mixer.sh must not force WirePlumber software mixing"
assert_not_contains "$SCRIPT" 'cp.*alsa-soft-mixer\.conf' \
  "fix-audio-mixer.sh must not install the soft-mixer override"

# 2. It must remove a previously-installed override so existing installs recover.
assert_contains "$SCRIPT" 'rm -f "\$soft_mixer_conf"' \
  "fix-audio-mixer.sh must remove any previously-forced soft-mixer override"

# 3. Hardware-agnostic: no per-machine gating.
assert_not_contains "$SCRIPT" 'ryoku-hw-asus-rog|/asus/' \
  "fix-audio-mixer.sh must stay hardware-agnostic (no per-machine gate)"

# 4. Keep the universal WirePlumber 40% default-sink-volume override.
assert_contains "$SCRIPT" 'device\.routes\.default-sink-volume=1\.0' \
  "fix-audio-mixer.sh must override WirePlumber's 40% default sink volume"

# 5. WirePlumber owns the levels now; the helper must only unmute the output
#    switches, never force a hardware level (which would override the slider).
assert_not_contains "$HELPER" '100%' \
  "audio mixer helper must not force a hardware level (WirePlumber owns the volume)"
assert_contains "$HELPER" 'set "\$ctl" unmute' \
  "audio mixer helper must unmute the hardware output switches"
assert_contains "$HELPER" '"Bass Speaker"' \
  "audio mixer helper should cover the laptop bass speaker switch"
assert_contains "$SCRIPT" '\$RYOKU_PATH/bin/ryoku-audio-restore-mixers' \
  "fix-audio-mixer.sh must delegate the unmute pass to the shared helper"

# 6. Existing installs recover through the migration.
assert_contains "$MIGRATION" 'install/config/hardware/fix-audio-mixer\.sh' \
  "recovery migration must source the updated mixer fix"

echo "PASS: global audio mixer (WirePlumber-native, no forced soft mixing)"
