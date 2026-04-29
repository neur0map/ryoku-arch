#!/bin/bash
# Static regression checks for the dashboard clock card.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

clock_card="config/quickshell/ryoku/vendor/brain-shell/src/services/home/ClockCard.qml"

[[ -f $clock_card ]] || fail "ClockCard.qml missing"

grep -q 'ClockCard - clock-only dashboard card' "$clock_card" \
  || fail "ClockCard should document the clock-only dashboard role"
grep -q 'Timer {' "$clock_card" \
  || fail "ClockCard should keep the wall-clock update timer"
grep -q 'function _tick()' "$clock_card" \
  || fail "ClockCard should keep the clock tick helper"
grep -q 'text: root._hStr' "$clock_card" \
  || fail "ClockCard should render the hour text"
grep -q 'text: root._mStr' "$clock_card" \
  || fail "ClockCard should render the minute text"
grep -q 'text: root._sec' "$clock_card" \
  || fail "ClockCard should render the seconds text"

! grep -q 'TabSwitcher' "$clock_card" \
  || fail "ClockCard should not render tabs"
! grep -q 'property string _mode' "$clock_card" \
  || fail "ClockCard should not keep page mode state"
! grep -q 'key: "timer"' "$clock_card" \
  || fail "ClockCard should not expose timer tab"
! grep -q 'key: "alarm"' "$clock_card" \
  || fail "ClockCard should not expose alarm tab"
! grep -q 'key: "stopwatch"' "$clock_card" \
  || fail "ClockCard should not expose stopwatch tab"
! grep -q 'ClockState' "$clock_card" \
  || fail "ClockCard should not sync timer/alarm/stopwatch state"
! grep -q 'TimeInput' "$clock_card" \
  || fail "ClockCard should not include timer/alarm input controls"
! grep -q 'notify-send' "$clock_card" \
  || fail "ClockCard should not include timer/alarm notification code"

pass "dashboard clock card is clock-only"
