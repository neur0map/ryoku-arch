#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_contains() {
  local path="$1"
  local pattern="$2"
  local message="$3"

  grep -Eq "$pattern" "$ROOT_DIR/$path" || fail "$message"
}

assert_contains shell/modules/dashboard/Content.qml 'function clampCurrentTab\(\): void' \
  "dashboard content should clamp the active tab when enabled tabs change"
assert_contains shell/modules/dashboard/Content.qml 'onDashboardTabCountChanged: clampCurrentTab\(\)' \
  "dashboard content should clamp immediately after tab model changes"
assert_contains shell/modules/dashboard/Content.qml 'enabledTabs\.length > 0 \? enabledTabs' \
  "dashboard content should keep a fallback tab when all configured tabs are disabled"
assert_contains shell/modules/dashboard/Tabs.qml 'readonly property int clampedCurrentIndex' \
  "dashboard tab bar should bind to a bounded tab index"
assert_contains shell/modules/dashboard/Tabs.qml 'count > 0 && currentIndex >= 0' \
  "dashboard tab bar should not publish negative indices during model rebuilds"
assert_contains shell/modules/dashboard/Tabs.qml 'TabBar\.tabBar && TabBar\.tabBar\.currentItem === this' \
  "dashboard tab delegates should tolerate transient TabBar detach during model rebuilds"

echo "PASS: dashboard tabs survive live settings reconfiguration"
