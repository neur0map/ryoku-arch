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

pane="shell/modules/controlcenter/notifications/NotificationsPane.qml"

assert_not_contains "$pane" "SectionContainer" \
  "notifications should not keep stacked generic section containers"
assert_not_contains "$pane" "SwitchRow" \
  "notifications should not keep long generic switch rows"
assert_not_contains "$pane" "SplitButtonRow" \
  "notifications should not keep dropdown-style fullscreen selectors"
assert_not_contains "$pane" "SpinBoxRow" \
  "notifications should not keep generic spinbox rows"
assert_not_contains "$pane" "MenuItem" \
  "notifications should not keep menu items for compact binary/mode choices"

assert_contains "$pane" "component NotificationConsole: StyledRect" \
  "notifications should expose a compact notification console"
assert_contains "$pane" "component ToastStackPreview: StyledRect" \
  "notifications should expose a toast stack preview"
assert_contains "$pane" "component FullscreenOption: StyledRect" \
  "notifications should expose segmented fullscreen options"
assert_contains "$pane" "component SignalChip: StyledRect" \
  "notifications should expose compact toast signal chips"
assert_contains "$pane" "component StepperTile: StyledRect" \
  "notifications should expose compact numeric steppers"

assert_contains "$pane" "GlobalConfig.notifs.expire = root.notificationsExpire" \
  "notifications should preserve expire backend writes"
assert_contains "$pane" "GlobalConfig.notifs.fullscreen = root.notificationsFullscreen" \
  "notifications should preserve notification fullscreen backend writes"
assert_contains "$pane" "GlobalConfig.utilities.toasts.fullscreen = root.toastsFullscreen" \
  "notifications should preserve toast fullscreen backend writes"
assert_contains "$pane" "GlobalConfig.utilities.toasts.audioOutputChanged = root.audioOutputChanged" \
  "notifications should preserve toast signal backend writes"
assert_contains "$pane" "checked: root.chargingChanged" \
  "toast signal chips should stay bound to live root state"

echo "PASS: tests/settings-notifications-console-remake.sh"
