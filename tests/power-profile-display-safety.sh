#!/bin/bash
# Static regression checks for dashboard power-profile display safety.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

power_profile="config/quickshell/ryoku/vendor/brain-shell/src/state/PowerProfile.qml"

[[ -f $power_profile ]] || fail "PowerProfile.qml missing"

grep -q 'brightnessctl -c backlight -m' "$power_profile" \
  || fail "PowerProfile should read only display backlight brightness"
grep -q 'brightnessctl -c backlight set' "$power_profile" \
  || fail "PowerProfile should set only display backlight brightness"

grep -q 'hyprctl.*keyword.*monitor' "$power_profile" \
  || fail "PowerProfile should keep the refresh-rate power-saving modeset"
! grep -q 'power_dpm_force_performance_level' "$power_profile" \
  || fail "PowerProfile should not force GPU DPM levels from the dashboard toggle"

pass "power profile display safety"
