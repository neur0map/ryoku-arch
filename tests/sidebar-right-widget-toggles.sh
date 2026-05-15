#!/bin/bash

# Regression checks for right-sidebar widget toggles in Settings.

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

assert_file() {
  local path="$1"
  [[ -f $ROOT_DIR/$path ]] || fail "$path should exist"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  assert_file "$path"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_not_contains() {
  local path="$1"
  local needle="$2"
  assert_file "$path"
  ! grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should not contain: $needle"
}

assert_matches() {
  local path="$1"
  local re="$2"
  assert_file "$path"
  grep -qE "$re" "$ROOT_DIR/$path" || fail "$path should match regex: $re"
}

settings_path="shell/modules/settings/InterfaceConfig.qml"

assert_not_contains "$settings_path" "Component.onCompleted: checked = rightSidebarWidgets.isEnabled"

toggle_count=$(grep -cF "onCheckedChanged: rightSidebarWidgets.setWidget" "$ROOT_DIR/$settings_path")
(( toggle_count == 11 )) || fail "right sidebar should expose 11 onCheckedChanged widget toggles"

for widget in calendar events todo notepad calculator sysmon timer openvpn hosts netmon firewall; do
  assert_contains "$settings_path" "rightSidebarWidgets.setWidget(\"$widget\", checked)"
done

assert_matches "$settings_path" '"calendar",[[:space:]]*"events",[[:space:]]*"todo"'
assert_matches "shell/modules/common/Config.qml" '"calendar",[[:space:]]*"events",[[:space:]]*"todo"'
assert_matches "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"calendar",[[:space:]]*"events",[[:space:]]*"todo"'
assert_matches "shell/modules/sidebarRight/CompactSidebarRightContent.qml" '"calendar",[[:space:]]*"events",[[:space:]]*"todo"'

echo "ok: sidebar-right-widget-toggles static asserts"
