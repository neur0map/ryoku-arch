#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

pane="shell/modules/controlcenter/taskbar/TaskbarPane.qml"

assert_not_contains "$pane" "SectionContainer" \
  "taskbar should not keep stacked generic section containers"
assert_not_contains "$pane" "SwitchRow" \
  "taskbar should not keep long generic switch rows"
assert_not_contains "$pane" "ConnectedButtonGroup" \
  "taskbar should not keep generic connected button groups"
assert_not_contains "$pane" "SliderInput" \
  "taskbar should not keep drawer-style slider input rows"
assert_not_contains "$pane" "component SettingsDeck" \
  "taskbar should not use generic settings deck cards"

assert_contains "$pane" "component BarCanvas: StyledRect" \
  "taskbar should expose a compact bar preview canvas"
assert_contains "$pane" "component ModuleToken: StyledRect" \
  "taskbar should expose taskbar module tokens"
assert_contains "$pane" "component WorkspaceRail: StyledRect" \
  "taskbar should expose a workspace rail editor"
assert_contains "$pane" "component StatusToken: StyledRect" \
  "taskbar should expose compact status icon tokens"
assert_not_contains "$pane" "checked: modelData.checked" \
  "taskbar status tokens should not use stale array-model checked state"
assert_contains "$pane" "component MonitorPill: StyledRect" \
  "taskbar should expose monitor visibility pills"
assert_contains "$pane" "component DialControl: StyledRect" \
  "taskbar should expose compact numeric controls"

assert_contains "$pane" "GlobalConfig.bar.status.showAudio = root.showAudio" \
  "taskbar should preserve status icon backend writes"
assert_contains "$pane" "checked: root.showAudio" \
  "taskbar audio token should stay bound to live status state"
assert_contains "$pane" "GlobalConfig.bar.entries = entries" \
  "taskbar should preserve module entries backend writes"
assert_contains "$pane" "GlobalConfig.bar.excludedScreens = root.excludedScreens" \
  "taskbar should preserve monitor exclusion backend writes"
assert_contains "$pane" "GlobalConfig.bar.workspaces.shown = root.workspacesShown" \
  "taskbar should preserve workspace count backend writes"
assert_contains "$pane" "GlobalConfig.bar.dragThreshold = root.dragThreshold" \
  "taskbar should preserve drag threshold backend writes"
assert_contains "$pane" "GlobalConfig.bar.popouts.statusIcons = root.popoutStatusIcons" \
  "taskbar should preserve popout backend writes"

echo "PASS: tests/settings-taskbar-editor-remake.sh"
