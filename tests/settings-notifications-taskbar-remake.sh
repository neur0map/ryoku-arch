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

notifications="shell/modules/controlcenter/notifications/NotificationsPane.qml"
taskbar="shell/modules/controlcenter/taskbar/TaskbarPane.qml"

assert_not_contains "$notifications" "SectionContainer" \
  "notifications should not keep old stacked section containers"
assert_not_contains "$notifications" "SwitchRow" \
  "notifications should use compact toggle tiles instead of long switch rows"
assert_not_contains "$notifications" "SplitButtonRow" \
  "notifications fullscreen choices should not be dropdown drawers"
assert_not_contains "$notifications" "SpinBoxRow" \
  "notifications numeric controls should be compact number tiles"
assert_not_contains "$notifications" "InnerBorder" \
  "notifications should use the shared compact pane viewport, not the old inset border shell"
assert_contains "$notifications" "component SettingsDeck: StyledRect" \
  "notifications should define compact decks"
assert_contains "$notifications" "component ModePill: StyledRect" \
  "notifications fullscreen options should be direct mode pills"
assert_contains "$notifications" "component ToggleChip: StyledRect" \
  "notifications toast event toggles should be compact chips"
assert_contains "$notifications" "component NumberStepper: StyledRect" \
  "notifications numeric settings should be compact steppers"
assert_contains "$notifications" "GlobalConfig.notifs.fullscreen = root.notificationsFullscreen" \
  "notifications should preserve fullscreen backend config"
assert_contains "$notifications" "GlobalConfig.utilities.toasts.nowPlaying = root.nowPlaying" \
  "notifications should preserve toast backend config"

assert_not_contains "$taskbar" "SectionContainer" \
  "taskbar should not keep old stacked section containers"
assert_not_contains "$taskbar" "SwitchRow" \
  "taskbar should use compact toggle tiles instead of long switch rows"
assert_not_contains "$taskbar" "ConnectedButtonGroup" \
  "taskbar should not keep the old button-group grid"
assert_not_contains "$taskbar" "InnerBorder" \
  "taskbar should use the shared compact pane viewport, not the old inset border shell"
assert_contains "$taskbar" "component BarPreview: StyledRect" \
  "taskbar should have a visual bar preview instead of opening on form rows"
assert_contains "$taskbar" "component SettingsDeck: StyledRect" \
  "taskbar should define compact decks"
assert_contains "$taskbar" "component ToggleChip: StyledRect" \
  "taskbar toggles should be compact chips"
assert_contains "$taskbar" "component NumberStepper: StyledRect" \
  "taskbar numeric settings should be compact steppers"
assert_contains "$taskbar" "component MonitorChip: ToggleChip" \
  "taskbar monitor exclusions should use compact chips"
assert_contains "$taskbar" "GlobalConfig.bar.entries = entries" \
  "taskbar should preserve entry ordering backend config"
assert_contains "$taskbar" "GlobalConfig.bar.status.showAudio = root.showAudio" \
  "taskbar should preserve status icon backend config"

echo "PASS: tests/settings-notifications-taskbar-remake.sh"
