#!/bin/bash

set -euo pipefail
cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  grep -Fq -- "$needle" "$path" || fail "$message"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq -- "$needle" "$path" || fail "$message"
}

island="shell/modules/island/Content.qml"
wrapper="shell/modules/island/Wrapper.qml"
ambxst_dir="shell/modules/island/ambxst"
panels="shell/modules/drawers/Panels.qml"
content_window="shell/modules/drawers/ContentWindow.qml"
helper="bin/ryoku-cmd-color-picker"

[[ -f $island ]] || fail "missing island content"
[[ -f $wrapper ]] || fail "missing island wrapper"
[[ -d $ambxst_dir ]] || fail "missing adapted Ambxst island directory"
[[ -f $helper ]] || fail "missing Ryoku color picker helper"
[[ -x $helper ]] || fail "Ryoku color picker helper should be executable"

bash -n "$helper" || fail "Ryoku color picker helper should be valid bash"

assert_contains "$helper" 'hyprpicker -a' \
  "color picker helper should use hyprpicker autocopy mode"
assert_contains "$helper" '--repeat' \
  "color picker helper should support repeated picks from the island"
assert_contains "$helper" 'while true' \
  "color picker helper should keep picking until the user cancels repeat mode"
assert_contains install/ryoku-base.packages 'hyprpicker' \
  "fresh installs should include hyprpicker for the island color picker"

for file in DashboardView.qml Dashboard.qml WidgetsTab.qml FullPlayer.qml QuickControls.qml ControlButton.qml NotificationHistory.qml VerticalControl.qml calendar/Calendar.qml calendar/CalendarDayButton.qml calendar/layout.js; do
  [[ -f $ambxst_dir/$file ]] || fail "missing adapted Ambxst component: $file"
done

assert_contains "$island" 'import "ambxst" as Ambxst' \
  "island content should host the adapted Ambxst component tree"
assert_contains "$island" 'Ambxst.DashboardView' \
  "island content should load the Ambxst dashboard view"
assert_contains "$island" 'property string mode: "dashboard"' \
  "island content should default to the Ambxst dashboard mode"
assert_contains "$island" 'mode === "record"' \
  "island content should dynamically switch into record mode"
assert_contains "$island" '["ryoku-cmd-google-lens"]' \
  "island Lens action should launch the Ryoku Google Lens helper"
assert_contains "$island" '["ryoku-cmd-color-picker", "--repeat"]' \
  "island color action should launch the repeatable Ryoku color picker helper"
assert_contains "$island" 'UtilityCards.Record' \
  "record quick action should open the existing recorder UI inside the island"
assert_contains "$island" 'Utilities.RecordingDeleteModal' \
  "record mode should preserve recording deletion confirmation inside the island"
assert_contains "$wrapper" 'Loader {' \
  "island wrapper should host the copied island through a Loader like settings"
assert_contains "$wrapper" 'active: root.shouldBeActive || root.visible' \
  "island wrapper should lazy-load content using the settings wrapper contract"

assert_contains "$ambxst_dir/DashboardView.qml" 'Adapted from Ambxst modules/widgets/dashboard/DashboardView.qml' \
  "dashboard view should preserve the Ambxst source boundary"
assert_contains "$ambxst_dir/DashboardView.qml" 'implicitWidth: 900' \
  "dashboard view should keep Ambxst's wide island footprint"
assert_contains "$ambxst_dir/DashboardView.qml" 'Dashboard {' \
  "dashboard view should host the copied Ambxst dashboard"

assert_contains "$ambxst_dir/Dashboard.qml" 'Adapted from Ambxst modules/widgets/dashboard/Dashboard.qml' \
  "dashboard should preserve the Ambxst source boundary"
assert_contains "$ambxst_dir/Dashboard.qml" 'WidgetsTab {' \
  "dashboard should render the Ambxst widgets tab"
assert_not_contains "$ambxst_dir/Dashboard.qml" 'UtilityCards.Toggles' \
  "dashboard should not replace Ambxst top controls with Ryoku's generic toggles card"

assert_contains "$ambxst_dir/WidgetsTab.qml" 'Adapted from Ambxst modules/widgets/dashboard/widgets/WidgetsTab.qml' \
  "widgets tab should preserve the Ambxst source boundary"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'FullPlayer {' \
  "widgets tab should include Ambxst's full vertical player"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'QuickControls {' \
  "widgets tab should keep the Ambxst quick controls on top"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'onRequestRecord: root.requestRecord()' \
  "widgets tab should bubble the record quick action to the island host"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'Calendar {' \
  "widgets tab should include the Ambxst calendar"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'NotificationHistory {' \
  "widgets tab should include the Ambxst notification panel"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'VerticalControl {' \
  "widgets tab should include the Ambxst right-side controls"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'Audio.volume' \
  "copied Ambxst island should keep the right-side volume control"
assert_contains "$ambxst_dir/WidgetsTab.qml" 'Audio.sourceVolume' \
  "copied Ambxst island should keep the right-side microphone control"

assert_contains "$ambxst_dir/FullPlayer.qml" 'Adapted from Ambxst modules/widgets/dashboard/widgets/FullPlayer.qml' \
  "full player should preserve the Ambxst source boundary"
assert_contains "$ambxst_dir/FullPlayer.qml" 'property bool playersListExpanded' \
  "full player should keep Ambxst's player selector overlay"
assert_contains "$ambxst_dir/FullPlayer.qml" 'Players.active' \
  "full player should adapt Ambxst MPRIS access to Ryoku's Players service"
assert_contains "$ambxst_dir/FullPlayer.qml" 'CircularProgress' \
  "full player should adapt Ambxst circular seek treatment to Ryoku controls"

assert_contains "$ambxst_dir/QuickControls.qml" 'Adapted from Ambxst modules/widgets/dashboard/widgets/QuickControls.qml' \
  "quick controls should preserve the Ambxst source boundary"
assert_contains "$ambxst_dir/QuickControls.qml" 'id: buttonRow' \
  "quick controls should keep toggles on the top row"
assert_contains "$ambxst_dir/QuickControls.qml" 'signal requestRecord' \
  "quick controls should expose the record quick action"
assert_contains "$ambxst_dir/QuickControls.qml" 'IdleInhibitor.enabled' \
  "quick controls should include keep-awake"
assert_contains "$ambxst_dir/QuickControls.qml" 'Nmcli.toggleWifi()' \
  "quick controls should include Wi-Fi"
assert_contains "$ambxst_dir/QuickControls.qml" 'Bluetooth.defaultAdapter' \
  "quick controls should include Bluetooth"
assert_contains "$ambxst_dir/QuickControls.qml" 'Notifs.dnd' \
  "quick controls should include notifications/DND"
assert_contains "$ambxst_dir/QuickControls.qml" 'GameMode.enabled' \
  "quick controls should include game mode"
assert_contains "$ambxst_dir/QuickControls.qml" 'iconName: "image_search"' \
  "quick controls should include Google Lens as a visible top action"
assert_contains "$ambxst_dir/QuickControls.qml" 'onClicked: root.requestLens()' \
  "Google Lens quick action should call the island host"
assert_contains "$ambxst_dir/QuickControls.qml" 'iconName: "colorize"' \
  "quick controls should include the color picker as a visible top action"
assert_contains "$ambxst_dir/QuickControls.qml" 'onClicked: root.requestColorPicker()' \
  "color picker quick action should call the island host"
assert_contains "$ambxst_dir/QuickControls.qml" 'iconName: "screen_record"' \
  "quick controls should include screen recording as a visible top action"
assert_contains "$ambxst_dir/QuickControls.qml" 'onClicked: root.requestRecord()' \
  "record quick action should call the island host"

assert_contains "$ambxst_dir/NotificationHistory.qml" 'Adapted from Ambxst modules/widgets/dashboard/widgets/NotificationHistory.qml' \
  "notification history should preserve the Ambxst source boundary"
assert_contains "$ambxst_dir/NotificationHistory.qml" 'Notifs.notClosed' \
  "notification history should use Ryoku's notification service"
assert_contains "$ambxst_dir/calendar/Calendar.qml" 'Adapted from Ambxst modules/widgets/dashboard/widgets/calendar/Calendar.qml' \
  "calendar should preserve the Ambxst source boundary"

assert_contains "$wrapper" 'required property BarPopouts.Wrapper popouts' \
  "island wrapper should receive the existing popout wrapper for reused utility controls"
assert_contains "$wrapper" 'readonly property PersistentProperties props' \
  "island wrapper should own persistent utility-card state"
assert_contains "$wrapper" 'property matrix4x4 deformMatrix' \
  "island wrapper should receive the blob deform matrix for utility modals"
assert_contains "$panels" 'popouts: root.popouts' \
  "drawer panels should pass popouts into the island"
assert_contains "$content_window" 'island.deformMatrix: islandBg.rawDeformMatrix' \
  "drawer content should pass the island blob deform matrix into the island"

echo "PASS: dynamic island hosts the adapted Ambxst island wrapper"
