#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
BATTERY_QML="shell/services/Battery.qml"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local pattern="$1"
  local message="$2"

  grep -Eq "$pattern" "$ROOT_DIR/$BATTERY_QML" || fail "$message"
}

assert_not_contains() {
  local pattern="$1"
  local message="$2"

  if grep -Eq "$pattern" "$ROOT_DIR/$BATTERY_QML"; then
    fail "$message"
  fi
}

assert_contains "_chargeLimitStateKnown" \
  "battery charge-limit state should be tracked before privileged writes"
assert_contains "function _chargeLimitMatches\\(enable: bool\\): bool" \
  "battery charge-limit startup sync should compare the current sysfs value"
assert_contains "function _setChargeLimitEnabled\\(enable: bool, forceIfUnknown: bool\\): void" \
  "battery charge-limit writes should go through read-first sync logic"
assert_contains "function _buildChargeLimitWriteCommand\\(enable: bool\\): var" \
  "battery charge-limit write command should be return-typed for QML linting"
assert_not_contains "onTriggered: root\\._applyChargeLimit\\(\\)" \
  "battery charge-limit startup timer must not unconditionally call pkexec"
assert_contains "_setChargeLimitEnabled\\(true, false\\)" \
  "battery charge-limit startup timer should skip pkexec when the current limit already matches"
assert_contains "/usr/bin/pkexec" \
  "battery charge-limit user changes still need the privileged write path"
