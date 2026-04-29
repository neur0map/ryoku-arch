#!/bin/bash
# Static checks for dashboard overlay controls and active display telemetry.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

home="config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashHome.qml"
topbar="config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml"
controls="config/quickshell/ryoku/vendor/brain-shell/src/services/home/DashboardTopControls.qml"
rail="config/quickshell/ryoku/vendor/brain-shell/src/services/home/TelemetryRail.qml"
qmldir="config/quickshell/ryoku/vendor/brain-shell/src/services/home/qmldir"

[[ -f $home ]] || fail "DashHome.qml missing"
[[ -f $topbar ]] || fail "TopBar.qml missing"
[[ -f $controls ]] || fail "DashboardTopControls.qml missing"
[[ -f $rail ]] || fail "TelemetryRail.qml missing"

! grep -Eq 'DashboardTopControls[[:space:]]*\{' "$home" \
  || fail "DashHome should not mount dashboard top controls over card content"
grep -q 'import "../services/home"' "$topbar" \
  || fail "TopBar should import dashboard top controls"
grep -Eq 'DashboardTopControls[[:space:]]*\{' "$topbar" \
  || fail "TopBar should mount dashboard top controls"
grep -Eq 'visible:[[:space:]]*Popups\.dashboardOpen' "$topbar" \
  || fail "Dashboard controls should appear only while dashboard is open"
grep -Eq 'anchors\.centerIn:[[:space:]]*parent' "$topbar" \
  || fail "Dashboard controls should be centered in the top notch"
grep -Eq 'horizontalCenterOffset:[[:space:]]*-12' "$topbar" \
  || fail "Dashboard controls should align to the clock card center"

for expected in \
  'readonly property int colW:     166' \
  'readonly property int centerW:  300' \
  'readonly property int railW:    190' \
  'readonly property int gap:        6' \
  'readonly property int profileH: 140' \
  'readonly property int clockH:   188'; do
  grep -q "$expected" "$home" || fail "DashHome layout changed: $expected"
done

grep -q 'DashboardTopControls DashboardTopControls.qml' "$qmldir" \
  || fail "DashboardTopControls should be exported"

grep -q 'Pipewire.defaultAudioSink' "$controls" \
  || fail "Top controls should bind to the default audio sink"
grep -q 'brightnessctl -c backlight -m' "$controls" \
  || fail "Top controls should read display backlight brightness"
grep -q 'brightnessctl -c backlight set' "$controls" \
  || fail "Top controls should set display backlight brightness"
grep -q 'property int  _brightnessTarget' "$controls" \
  || fail "Top controls should freeze the requested brightness target before writing"
grep -q 'if (root._brightnessBusy) return' "$controls" \
  || fail "Top controls should ignore stale brightness reads while a write is pending"
awk '/function setBrightness/,/^    }/' "$controls" | grep -q 'root._brightnessBusy = true' \
  || fail "Top controls should mark brightness busy as soon as the user drags"
awk '/function setBrightness/,/^    }/' "$controls" | grep -q 'root._brightnessTarget =' \
  || fail "Top controls should update the write target from user input"
! grep -q 'ryoku-brightness-debug' "$controls" \
  || fail "Top controls should not keep temporary brightness diagnostics"
grep -q 'height: 24' "$controls" \
  || fail "Top controls should fill the top notch more visibly"
grep -q 'strokeWidth: 2' "$controls" \
  || fail "Top controls should use readable wave strokes"
grep -q 'amplitude: 2.4' "$controls" \
  || fail "Top controls should use larger wave amplitude"
grep -q 'id: controlHit' "$controls" \
  || fail "Top controls should expose a full-capsule drag hit area"
grep -q 'anchors.fill: parent' "$controls" \
  || fail "Top controls should allow dragging across the visible capsule"
[[ $(grep -cE 'WaveBar[[:space:]]*\{' "$controls") -eq 1 ]] \
  || fail "Top controls should use one reusable WaveBar in its control component"
grep -q 'label: "VOL"' "$controls" \
  || fail "Top controls should include VOL wave control"
grep -q 'label: "BRI"' "$controls" \
  || fail "Top controls should include BRI wave control"

grep -q '"hyprctl", "monitors", "-j"' "$rail" \
  || fail "Telemetry rail should read monitor state"
grep -q 'property string activeDisplayName' "$rail" \
  || fail "Telemetry rail should track active display name"
grep -q 'property int currentDisplayRefreshHz' "$rail" \
  || fail "Telemetry rail should track current display Hz"
grep -q 'currentDisplayRefreshHz + " Hz"' "$rail" \
  || fail "Telemetry rail should render current display Hz"
grep -q 'property string displaySummary' "$rail" \
  || fail "Telemetry rail should render display name and current Hz as one compact summary"
grep -q 'root.currentDisplayRefreshHz = Math.round(mon.refreshRate' "$rail" \
  || fail "Telemetry rail should display the active refreshRate"
grep -q 'target: PowerProfile' "$rail" \
  || fail "Telemetry rail should react to power-profile display changes"
grep -q 'onDisplayRefreshGenerationChanged' "$rail" \
  || fail "Telemetry rail should refresh after power-profile display changes"

pass "dashboard top controls and active display Hz"
