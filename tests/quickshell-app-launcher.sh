#!/bin/bash
# Static regression checks for the Quickshell app launcher.

set -e
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

pass() {
  echo "OK: $1"
}

shell="config/quickshell/ryoku/shell.qml"
popups="config/quickshell/ryoku/vendor/brain-shell/src/state/Popups.qml"
topbar="config/quickshell/ryoku/vendor/brain-shell/src/windows/TopBar.qml"
layer="config/quickshell/ryoku/vendor/brain-shell/src/popups/PopupLayer.qml"
launcher_popup="config/quickshell/ryoku/vendor/brain-shell/src/popups/AppLauncherPopup.qml"
launcher="config/quickshell/ryoku/vendor/brain-shell/src/services/AppLauncher.qml"
popup_dismiss="config/quickshell/ryoku/vendor/brain-shell/src/windows/PopupDismiss.qml"
bindings="default/hypr/bindings/utilities.conf"

[[ -f $shell ]] || fail "shell.qml missing"
[[ -f $popups ]] || fail "Popups.qml missing"
[[ -f $topbar ]] || fail "TopBar.qml missing"
[[ -f $layer ]] || fail "PopupLayer.qml missing"
[[ -f $launcher_popup ]] || fail "AppLauncherPopup.qml missing"
[[ -f $launcher ]] || fail "AppLauncher.qml missing"
[[ -f $popup_dismiss ]] || fail "PopupDismiss.qml missing"
[[ -f $bindings ]] || fail "utilities keybindings missing"

grep -q 'function toggleLauncher' "$shell" \
  || fail "shell IPC should expose toggleLauncher"
grep -q 'BS.Popups.launcherOpen = opening' "$shell" \
  || fail "toggleLauncher should open launcher after closing other popups"
grep -q 'property bool launcherOpen' "$popups" \
  || fail "Popups should track launcherOpen"
grep -q 'property bool launcherVisible' "$popups" \
  || fail "Popups should track launcher visual presence"
! awk '/readonly property bool anyOpen:/,/function closeAll/' "$popups" | grep -q 'launcherOpen' \
  || fail "PopupDismiss should not be responsible for launcher outside-click handling"
grep -q 'Popups.dashboardVisible || Popups.launcherVisible' "$topbar" \
  || fail "TopBar should stay visually connected while launcher opens"
grep -q 'AppLauncherPopup' "$layer" \
  || fail "PopupLayer should instantiate AppLauncherPopup"

grep -q 'PanelWindow' "$launcher_popup" \
  || fail "AppLauncherPopup should be its own layer shell window"
grep -q 'WlrKeyboardFocus.Exclusive' "$launcher_popup" \
  || fail "AppLauncherPopup should own keyboard focus while open"
grep -q 'Popups.launcherOpen || Popups.wallpaperOpen || Popups.toolboxOpen ? WlrKeyboardFocus.None : WlrKeyboardFocus.OnDemand' "$popup_dismiss" \
  || fail "PopupDismiss should not steal keyboard focus from focus-owned popups"
grep -q 'Binding { target: Popups; property: "launcherVisible"' "$launcher_popup" \
  || fail "AppLauncherPopup should expose visual presence to TopBar"
grep -q 'launcherWidth: Math.min(420, Theme.dashboardWidth)' "$launcher_popup" \
  || fail "AppLauncherPopup should stay compact"
grep -q 'launcherHeight: Math.min(320, Theme.dashboardHeight)' "$launcher_popup" \
  || fail "AppLauncherPopup should stay compact vertically"
grep -q 'bottom: true' "$launcher_popup" \
  || fail "AppLauncherPopup should own outside-click area"
grep -q 'onClicked: Popups.closeAll()' "$launcher_popup" \
  || fail "AppLauncherPopup should close itself when clicking outside"
! grep -q 'mask: Region' "$launcher_popup" \
  || fail "AppLauncherPopup should not mask away its outside-click area"
grep -q 'property real openProgress' "$launcher_popup" \
  || fail "AppLauncherPopup should animate open progress"
grep -q 'Theme.motionExpandDuration' "$launcher_popup" \
  || fail "AppLauncherPopup should reuse shell expand timing"
grep -q 'AppLauncher {' "$launcher_popup" \
  || fail "AppLauncherPopup should mount the Brain Shell launcher"
grep -q 'active: Popups.launcherOpen' "$launcher_popup" \
  || fail "AppLauncher should reload when the launcher opens"

grep -q 'property bool launchPending' "$launcher" \
  || fail "AppLauncher should hold launch state for row animation"
grep -q 'property bool active' "$launcher" \
  || fail "AppLauncher should support explicit popup activation"
grep -q 'vendor/brain-shell/src/scripts/list_apps.py' "$launcher" \
  || fail "AppLauncher should load apps from Ryoku's vendored Brain Shell path"
grep -q 'Timer {' "$launcher" \
  || fail "AppLauncher should delay process launch briefly"
grep -q 'launchTimer.restart' "$launcher" \
  || fail "AppLauncher should start the launch animation before exec"
grep -q 'Popups.launcherOpen = false' "$launcher" \
  || fail "AppLauncher should close launcher after launching"
grep -q 'scale: isLaunching' "$launcher" \
  || fail "App rows should visibly animate when opened"
grep -q 'height: 40' "$launcher" \
  || fail "AppLauncher rows should be compact"
grep -q 'height: 38' "$launcher" \
  || fail "AppLauncher search bar should be compact"
grep -q 'Popups.launcherOpen = false' "$launcher" \
  || fail "Escape should close the launcher when search is empty"
! grep -q 'Popups.dashboardOpen = false' "$launcher" \
  || fail "Launcher should not try to close dashboard on Escape"

grep -q 'bindd = SUPER, SPACE, Launch apps, exec, qs -c ryoku ipc call popups toggleLauncher' "$bindings" \
  || fail "SUPER+SPACE should open the Quickshell launcher"
! grep -q 'bindd = SUPER, SPACE, Launch apps, exec, ryoku-launch-drun' "$bindings" \
  || fail "SUPER+SPACE should no longer use the old tofi/fuzzel launcher"

pass "quickshell app launcher wiring"
