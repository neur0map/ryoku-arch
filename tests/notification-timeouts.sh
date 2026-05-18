#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local needle="$2"

  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

jq -e '.notifications.maxPopupLifetime == 30000' "$ROOT_DIR/shell/defaults/config.json" >/dev/null \
  || fail "defaults should cap persistent notification popups"

assert_contains "shell/modules/common/Config.qml" "property int maxPopupLifetime: 30000"
assert_contains "shell/services/Notifications.qml" "notification.urgency === NotificationUrgency.Low"
assert_contains "shell/services/Notifications.qml" "notification.urgency === NotificationUrgency.Critical"
assert_contains "shell/services/Notifications.qml" "return (critTimeout === 0 && maxLifetime > 0) ? maxLifetime : critTimeout;"
assert_contains "shell/services/Notifications.qml" "return maxLifetime;"

if grep -qF "urgencyStr ===" "$ROOT_DIR/shell/services/Notifications.qml"; then
  fail "notification urgency should use enum comparison, not strings"
fi

echo "PASS: notification timeout defaults and urgency handling"
