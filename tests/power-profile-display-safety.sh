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
shell="config/quickshell/ryoku/shell.qml"
overlay="config/quickshell/ryoku/vendor/brain-shell/src/windows/DisplayTransitionOverlay.qml"

[[ -f $power_profile ]] || fail "PowerProfile.qml missing"
[[ -f $shell ]] || fail "shell.qml missing"

grep -q 'brightnessctl -c backlight -m' "$power_profile" \
  || fail "PowerProfile should read only display backlight brightness"
grep -q 'brightnessctl -c backlight set' "$power_profile" \
  || fail "PowerProfile should set only display backlight brightness"

grep -q 'hyprctl.*keyword.*monitor' "$power_profile" \
  || fail "PowerProfile should keep the refresh-rate power-saving modeset"
grep -q 'property bool displayTransitionActive' "$power_profile" \
  || fail "PowerProfile should expose display transition overlay state"
grep -q 'readonly property int displayTransitionPreDelay' "$power_profile" \
  || fail "PowerProfile should delay display mode changes until blackout is visible"
grep -q 'readonly property int displayTransitionPostDelay' "$power_profile" \
  || fail "PowerProfile should hold blackout after display mode changes"
grep -q 'property int displayRefreshGeneration' "$power_profile" \
  || fail "PowerProfile should notify telemetry after refresh changes"
grep -q 'function _maxRefreshHz(mon)' "$power_profile" \
  || fail "PowerProfile should derive max refresh from available modes"
grep -q 'function _targetRefreshForMode(mon, target)' "$power_profile" \
  || fail "PowerProfile should choose refresh targets by requested mode"
grep -q 'target === "performance"' "$power_profile" \
  || fail "PowerProfile should explicitly restore max Hz in performance mode"
! grep -q '_setMonitorRefresh(root.savedRefresh)' "$power_profile" \
  || fail "PowerProfile should not restore stale saved refresh"
! grep -q 'power_dpm_force_performance_level' "$power_profile" \
  || fail "PowerProfile should not force GPU DPM levels from the dashboard toggle"

[[ -f $overlay ]] || fail "DisplayTransitionOverlay.qml missing"
grep -q 'PanelWindow\s*{' "$overlay" \
  || fail "Display transition overlay should be a PanelWindow"
grep -q 'WlrLayershell\.layer:\s*WlrLayer\.Overlay' "$overlay" \
  || fail "Display transition overlay should sit on the overlay layer"
grep -q 'color:\s*"#000000"' "$overlay" \
  || fail "Display transition overlay should black out the screen"
grep -q 'PowerProfile\.displayTransitionActive' "$overlay" \
  || fail "Display transition overlay should follow PowerProfile state"
grep -q 'Behavior on opacity' "$overlay" \
  || fail "Display transition overlay should fade in and out"
grep -q 'PowerProfile\.displayTransitionFadeDuration' "$overlay" \
  || fail "Display transition overlay should use PowerProfile timing"
grep -q 'BSW.DisplayTransitionOverlay' "$shell" \
  || fail "shell.qml should mount the display transition overlay"

pass "power profile display safety"
