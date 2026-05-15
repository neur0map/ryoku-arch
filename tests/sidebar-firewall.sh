#!/bin/bash

# Static asserts for the Firewall sidebar tab. Mirrors the Hosts and
# Network Monitor sidebar tab tests.

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

# 1. Helper script: UFW-first helper with status JSON, guarded privileged
#    operations, and a Ryoku-default recovery action rather than a raw reset.
assert_executable "bin/ryoku-firewall"
assert_contains   "bin/ryoku-firewall" "status)"
assert_contains   "bin/ryoku-firewall" "add)"
assert_contains   "bin/ryoku-firewall" "delete)"
assert_contains   "bin/ryoku-firewall" "enable)"
assert_contains   "bin/ryoku-firewall" "disable)"
assert_contains   "bin/ryoku-firewall" "default)"
assert_contains   "bin/ryoku-firewall" "restore-defaults)"
assert_contains   "bin/ryoku-firewall" "/etc/ufw/user.rules"
assert_contains   "bin/ryoku-firewall" "/etc/ufw/user6.rules"
assert_contains   "bin/ryoku-firewall" "/etc/default/ufw"
assert_contains   "bin/ryoku-firewall" '${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/firewall'
assert_contains   "bin/ryoku-firewall" "pkexec"
assert_contains   "bin/ryoku-firewall" "53317"
assert_contains   "bin/ryoku-firewall" "allow-docker-dns"

# 2. Service singleton + qmldir registration. The service exposes typed
#    firewall state, gated refresh, busy/error state, and action methods.
assert_file       "shell/services/RyokuFirewall.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuFirewall 1.0 RyokuFirewall.qml"
assert_contains   "shell/services/RyokuFirewall.qml" "ryoku-firewall"
assert_matches    "shell/services/RyokuFirewall.qml" 'property var rules'
assert_matches    "shell/services/RyokuFirewall.qml" 'property bool tabOpen'
assert_contains   "shell/services/RyokuFirewall.qml" "GlobalStates.sidebarRightOpen && root.tabOpen"
assert_contains   "shell/services/RyokuFirewall.qml" "function addRule"
assert_contains   "shell/services/RyokuFirewall.qml" "function deleteRule"
assert_contains   "shell/services/RyokuFirewall.qml" "function restoreDefaults"
assert_contains   "shell/services/RyokuFirewall.qml" "function setDefaultPolicy"
assert_contains   "shell/services/RyokuFirewall.qml" "busyTimeout"
assert_contains   "shell/services/RyokuFirewall.qml" "JSON.parse"

# 3. Sidebar tab widget exists, binds to RyokuFirewall, has an advanced
#    toggle, and marks risky actions with the Material error color.
assert_file       "shell/modules/sidebarRight/firewall/FirewallTab.qml"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "RyokuFirewall.rules"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "RyokuFirewall.addRule("
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "RyokuFirewall.deleteRule("
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "RyokuFirewall.restoreDefaults()"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "advancedVisible"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "Restore Ryoku defaults"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "Appearance.m3colors.m3error"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "MaterialTextField"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" "DialogButton"
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" '"shield"'
assert_contains   "shell/modules/sidebarRight/firewall/FirewallTab.qml" '"delete"'

# 4. BottomWidgetGroup imports the firewall module, wraps FirewallTab in a
#    Component, declares the tab, drives RyokuFirewall.tabOpen, and includes
#    "firewall" in the enabledWidgets fallback default.
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "import qs.modules.sidebarRight.firewall"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "id: firewallWidgetComponent"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"type": "firewall"'
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "target: RyokuFirewall"
assert_matches    "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"netmon",[[:space:]]*"firewall"'

# 5. CompactSidebarRightContent imports the firewall module, wraps the tab,
#    declares the section, drives RyokuFirewall.tabOpen, and includes it in
#    the enabledWidgets fallback default.
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "import qs.modules.sidebarRight.firewall"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "id: firewallComponent"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" 'id: "firewall"'
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "target: RyokuFirewall"
assert_matches    "shell/modules/sidebarRight/CompactSidebarRightContent.qml" '"netmon",[[:space:]]*"firewall"'

# 6. Defaults and Settings include the tab so fresh installs show it and the
#    Settings toggle cannot silently drop it.
assert_json_expr  "shell/defaults/config.json" '.sidebar.right.enabledWidgets | index("firewall") != null' \
  "shell defaults should include 'firewall' in sidebar.right.enabledWidgets"
assert_matches    "shell/modules/common/Config.qml" '"netmon",[[:space:]]*"firewall"'
assert_matches    "shell/modules/settings/InterfaceConfig.qml" '"netmon",[[:space:]]*"firewall"'
assert_contains   "shell/modules/settings/InterfaceConfig.qml" "rightSidebarWidgets.setWidget(\"firewall\", checked)"

# 7. Migration appends firewall for existing users with explicit widget lists.
operator_migration=$(grep -lE 'enabledWidgets.*firewall|index\("firewall"\)' "$ROOT_DIR"/migrations/*.sh 2>/dev/null | head -1)
[[ -n $operator_migration ]] || fail "a migration should append firewall to enabledWidgets"

echo "ok: sidebar-firewall static asserts"
