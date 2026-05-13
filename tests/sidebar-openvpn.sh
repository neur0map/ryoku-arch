#!/bin/bash

# Static asserts for the OpenVPN sidebar feature. Mirrors the style
# of other shell-feature tests.

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

assert_executable() {
  local path="$1"
  assert_file "$path"
  [[ -x $ROOT_DIR/$path ]] || fail "$path should be executable"
}

assert_contains() {
  local path="$1"
  local needle="$2"
  assert_file "$path"
  grep -qF "$needle" "$ROOT_DIR/$path" || fail "$path should contain: $needle"
}

assert_matches() {
  local path="$1"
  local re="$2"
  assert_file "$path"
  grep -qE "$re" "$ROOT_DIR/$path" || fail "$path should match regex: $re"
}

assert_json_expr() {
  local path="$1"
  local jq_expr="$2"
  local message="$3"

  assert_file "$path"
  jq -e "$jq_expr" "$ROOT_DIR/$path" >/dev/null || fail "$message"
}

# 1. Service singleton
assert_file       "shell/services/RyokuOpenVpn.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuOpenVpn 1.0 RyokuOpenVpn.qml"

# 2. Sidebar widgets
assert_file       "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml"
assert_file       "shell/modules/sidebarRight/openvpn/OpenVpnStatusCard.qml"
assert_file       "shell/modules/sidebarRight/openvpn/OpenVpnProfileRow.qml"
assert_file       "shell/modules/sidebarRight/openvpn/OpenVpnLogTail.qml"

# 3. Tab is wired into BottomWidgetGroup
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"type": "openvpn"'
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "openVpnWidgetComponent"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" 'import qs.modules.sidebarRight.openvpn'
# Authoritative tabOpen Binding (lifecycle fix from holistic UI review)
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" 'property: "tabOpen"'

# 4. Config defaults
assert_matches    "shell/modules/common/Config.qml" '"openvpn"'
assert_json_expr  "shell/defaults/config.json" '.sidebar.right.enabledWidgets | index("openvpn") != null' \
  "shell defaults should enable the OpenVPN sidebar tab"

# 5. Bash helpers
assert_executable "bin/ryoku-openvpn-import"
assert_executable "bin/ryoku-openvpn-remove"
assert_executable "bin/ryoku-openvpn-rename"

# 6. Polkit + installer
assert_file       "default/polkit/49-ryoku-openvpn.rules"
assert_executable "install/config/openvpn.sh"
assert_contains   "install/config/all.sh" "openvpn.sh"
assert_contains   "install/config/openvpn.sh" 'chmod 0755 /etc/openvpn/client'
assert_contains   "migrations/1778633301.sh" 'install/config/openvpn.sh'
assert_contains   "migrations/1778633301.sh" 'Converge VPN service setup'

# 7. openvpn package
assert_contains   "install/ryoku-base.packages" "openvpn"

printf 'PASS: tests/sidebar-openvpn.sh\n'
