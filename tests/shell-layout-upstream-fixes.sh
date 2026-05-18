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

  grep -qF "$needle" "$path" || fail "$path should contain: $needle"
}

search_widget="shell/modules/overview/SearchWidget.qml"
update_indicator="shell/modules/bar/ShellUpdateIndicator.qml"
all_apps="shell/modules/waffle/startMenu/AllAppsContent.qml"
start_page="shell/modules/waffle/startMenu/StartPageContent.qml"

assert_contains "$search_widget" "height: searchWidgetContent.height"
! grep -qF "height: searchWidgetContent.width" "$search_widget" \
  || fail "overview mask should not use width as height"

assert_contains "$update_indicator" "readonly property int updatePopupWidth: 380"
assert_contains "$update_indicator" "ShellUpdates.updateStepMessage"
assert_contains "$update_indicator" "elide: Text.ElideRight"
assert_contains "$update_indicator" "text: ShellUpdates.currentBranch"
assert_contains "$update_indicator" "elide: Text.ElideMiddle"

assert_contains "$all_apps" "Flow {"
assert_contains "$all_apps" "id: appFlow"
assert_contains "$all_apps" "anchors.horizontalCenter: parent.horizontalCenter"
assert_contains "$all_apps" "LaunchUtils.launchDesktopEntry(appBtn.modelData)"
assert_contains "$start_page" "Flow {"
assert_contains "$start_page" "id: pinnedFlow"
assert_contains "$start_page" "Math.min(6, Math.floor"
assert_contains "$start_page" "anchors.horizontalCenter: parent.horizontalCenter"

echo "PASS: shell layout upstream fixes are wired"
