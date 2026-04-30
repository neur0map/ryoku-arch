#!/bin/bash
# Static regression checks for right topbar status icons.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

audio="config/quickshell/ryoku/vendor/brain-shell/src/modules/Right/Audio.qml"
battery_status="config/quickshell/ryoku/vendor/brain-shell/src/services/BatteryStatus.qml"

for path in "$audio" "$battery_status"; do
  [[ -f $path ]] || fail "$path missing"
done

! grep -q 'HoverHandler' "$audio" \
  || fail "speaker icon should not have hover handling"
! grep -q 'hov.hovered' "$audio" \
  || fail "speaker icon should not change on hover"
! grep -q 'HoverHandler' "$battery_status" \
  || fail "battery icon should not have hover handling"
! grep -q 'hov.hovered' "$battery_status" \
  || fail "battery icon should not change on hover"

pass "right topbar status icons do not react to hover"
