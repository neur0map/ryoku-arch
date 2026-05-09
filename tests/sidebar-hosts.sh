#!/bin/bash

# Static asserts for the Hosts sidebar tab. Mirrors the style of
# tests/sidebar-openvpn.sh and tests/sidebar-tailscale.sh. Spec:
# docs/superpowers/specs/2026-05-08-hosts-sidebar-tab-design.md.

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

# 1. Helper script: pkexec writer with add/remove subcommands and the
#    canonical state-file location.
assert_executable "bin/ryoku-hosts-edit"
assert_contains   "bin/ryoku-hosts-edit" "pkexec install -m 644"
assert_contains   "bin/ryoku-hosts-edit" '# >>> ryoku-hosts (managed) >>>'
assert_contains   "bin/ryoku-hosts-edit" '# <<< ryoku-hosts (managed) <<<'
assert_contains   "bin/ryoku-hosts-edit" '${XDG_STATE_HOME:-$HOME/.local/state}/ryoku/hosts'
assert_matches    "bin/ryoku-hosts-edit" '^[[:space:]]*case [^)]+ in$'
assert_contains   "bin/ryoku-hosts-edit" "ok-noop"
assert_contains   "bin/ryoku-hosts-edit" "is_v4"
assert_contains   "bin/ryoku-hosts-edit" "is_v6"
assert_contains   "bin/ryoku-hosts-edit" "is_domain"


# 2. Service singleton + qmldir registration. Service exposes add/remove
#    action methods, parses the managed block, and watches both
#    /etc/hosts and the helper's last-op.json status manifest.
assert_file       "shell/services/RyokuHosts.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuHosts 1.0 RyokuHosts.qml"
assert_contains   "shell/services/RyokuHosts.qml" "function add"
assert_contains   "shell/services/RyokuHosts.qml" "function remove"
assert_contains   "shell/services/RyokuHosts.qml" 'Quickshell.execDetached(["ryoku-hosts-edit"'
assert_matches    "shell/services/RyokuHosts.qml" "ryoku-hosts.*managed"
assert_contains   "shell/services/RyokuHosts.qml" "/etc/hosts"
assert_matches    "shell/services/RyokuHosts.qml" 'property bool tabOpen'
assert_contains   "shell/services/RyokuHosts.qml" "property bool busy"
assert_contains   "shell/services/RyokuHosts.qml" "busyTimeout"
assert_contains   "shell/services/RyokuHosts.qml" "JSON.parse"


# 3. Sidebar tab widget exists, binds to RyokuHosts state, calls add()
#    and remove(), and uses the canonical "dns" + "close" Material symbols.
assert_file       "shell/modules/sidebarRight/hosts/HostsTab.qml"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.entries"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.add("
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.remove("
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" '"dns"'
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" '"close"'
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "RyokuHosts.clearError()"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "!RyokuHosts.busy"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "_isValidIp"
assert_contains   "shell/modules/sidebarRight/hosts/HostsTab.qml" "_isValidDomain"


# 4. BottomWidgetGroup imports the hosts module, wraps HostsTab in a
#    Component, declares the tab in allTabs, drives RyokuHosts.tabOpen,
#    and includes "hosts" in the enabledWidgets fallback default.
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "import qs.modules.sidebarRight.hosts"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "id: hostsWidgetComponent"
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"type": "hosts"'
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "target: RyokuHosts"
assert_matches    "shell/modules/sidebarRight/BottomWidgetGroup.qml" '"openvpn",[[:space:]]*"hosts"'


# 5. CompactSidebarRightContent imports the hosts module, wraps HostsTab
#    in a Component, declares the section in widgetSections, drives
#    RyokuHosts.tabOpen, and includes "hosts" in the enabledWidgets
#    fallback default.
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "import qs.modules.sidebarRight.hosts"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "id: hostsComponent"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" 'id: "hosts"'
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "target: RyokuHosts"
assert_matches    "shell/modules/sidebarRight/CompactSidebarRightContent.qml" '"openvpn",[[:space:]]*"hosts"'

# 6. Shell defaults include "hosts" in sidebar.right.enabledWidgets so
#    the tab appears for fresh installs. Settings UI's duplicated defaults
#    array also includes "hosts" so toggling any widget in Settings does
#    not silently drop the tab from the user's enabledWidgets.
assert_json_expr  "shell/defaults/config.json" '.sidebar.right.enabledWidgets | index("hosts") != null' \
  "shell defaults should include 'hosts' in sidebar.right.enabledWidgets"
assert_matches    "shell/modules/settings/InterfaceConfig.qml" '"openvpn",[[:space:]]*"hosts"'
assert_matches    "shell/modules/common/Config.qml" '"openvpn",[[:space:]]*"hosts"'

echo "ok: sidebar-hosts static asserts"
