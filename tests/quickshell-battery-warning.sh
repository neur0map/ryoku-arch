#!/bin/bash
# Static regression checks for the low-battery warning toast.

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

warning="config/quickshell/ryoku/vendor/brain-shell/src/services/BatteryWarning.qml"
status="config/quickshell/ryoku/vendor/brain-shell/src/services/BatteryStatus.qml"
popups="config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml"
shell="config/quickshell/ryoku/shell.qml"
ipc="bin/ryoku-ipc"

[[ -f $warning ]] || fail "$warning missing"
[[ -f $status ]] || fail "$status missing"
[[ -f $popups ]] || fail "$popups missing"
[[ -f $shell ]] || fail "$shell missing"
[[ -x $ipc ]] || fail "$ipc missing or not executable"

grep -q 'PanelWindow {' "$warning" \
  || fail "BatteryWarning should use a positioned PanelWindow"
! grep -q 'FloatingWindow {' "$warning" \
  || fail "BatteryWarning should not be a WM-centered FloatingWindow"
grep -q 'anchors.top: true' "$warning" \
  || fail "BatteryWarning should anchor to the top edge"
grep -q 'anchors.right: true' "$warning" \
  || fail "BatteryWarning should anchor to the right edge"
grep -q 'implicitWidth: 260' "$warning" \
  || fail "BatteryWarning should be slimmer than the old 320px card"
grep -q 'implicitHeight: 64' "$warning" \
  || fail "BatteryWarning should be shorter than the old 100px card"
grep -q 'WlrLayershell.layer: WlrLayer.Overlay' "$warning" \
  || fail "BatteryWarning should stay above normal windows"
grep -q 'WlrLayershell.keyboardFocus: WlrKeyboardFocus.None' "$warning" \
  || fail "BatteryWarning should not take keyboard focus"
grep -q 'exclusionMode: ExclusionMode.Ignore' "$warning" \
  || fail "BatteryWarning should not reserve screen space"
! grep -q 'wrapMode: *Text.WordWrap' "$warning" \
  || fail "BatteryWarning should not use a large wrapped body message"

grep -q 'warningWindow.warnLevel = lvl' "$status" \
  || fail "BatteryStatus should still set warning severity"
grep -q 'warningWindow.visible   = true' "$status" \
  || fail "BatteryStatus should still show the warning window"
grep -q 'signal batteryWarningRequested(int level)' "$popups" \
  || fail "Popups should expose a battery warning preview signal"
grep -q 'function requestBatteryWarning(level)' "$popups" \
  || fail "Popups should expose a battery warning preview helper"
grep -q 'function previewBatteryWarning(): void' "$shell" \
  || fail "shell IPC should expose previewBatteryWarning"
grep -q 'onBatteryWarningRequested' "$status" \
  || fail "BatteryStatus should respond to battery warning preview requests"
"$ipc" --help | grep -q 'ryoku-ipc shell preview battery-warning' \
  || fail "ryoku-ipc help should document battery warning preview"
"$ipc" shell command battery-warning | grep -q 'qs -c ryoku ipc call popups previewBatteryWarning' \
  || fail "ryoku-ipc should print the battery warning preview command"

pass "quickshell battery warning toast"
