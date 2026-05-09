#!/bin/bash

# Static asserts for the Network Monitor sidebar tab. Mirrors the style
# of tests/sidebar-openvpn.sh, tests/sidebar-tailscale.sh, and
# tests/sidebar-hosts.sh. Spec:
# docs/superpowers/specs/2026-05-08-network-monitor-tab-design.md.

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

# 1. Helper script: emits one JSON blob with addrs/routes/links/nmcli/wifi/dns.
assert_executable "bin/ryoku-netmon-collect"
assert_contains   "bin/ryoku-netmon-collect" "ip -j addr show"
assert_contains   "bin/ryoku-netmon-collect" "ip -j route show default"
assert_contains   "bin/ryoku-netmon-collect" "ip -j -s link show"
assert_contains   "bin/ryoku-netmon-collect" "nmcli"
assert_contains   "bin/ryoku-netmon-collect" "resolvectl"
assert_contains   "bin/ryoku-netmon-collect" "addrs"
assert_contains   "bin/ryoku-netmon-collect" "wifi"

# 2. Service singleton + qmldir registration. Service exposes the typed
#    surface, polls via the helper, and runs DNS-leak detection.
assert_file       "shell/services/RyokuNetMon.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuNetMon 1.0 RyokuNetMon.qml"
assert_contains   "shell/services/RyokuNetMon.qml" "ryoku-netmon-collect"
assert_matches    "shell/services/RyokuNetMon.qml" 'property var interfaces'
assert_matches    "shell/services/RyokuNetMon.qml" 'property bool tabOpen'
assert_contains   "shell/services/RyokuNetMon.qml" "GlobalStates.sidebarRightOpen && root.tabOpen"
assert_contains   "shell/services/RyokuNetMon.qml" "function refreshPublicIp"
assert_matches    "shell/services/RyokuNetMon.qml" '\^\(tun\|wg\|tailscale\)'
assert_contains   "shell/services/RyokuNetMon.qml" "dnsLeak"
assert_contains   "shell/services/RyokuNetMon.qml" "proxychain"
assert_contains   "shell/services/RyokuNetMon.qml" "https://api.ipify.org"

# 3. Sidebar tab widget exists, binds to RyokuNetMon, surfaces egress
#    strip + DNS-leak banner + proxychain card + per-iface cards.
assert_file       "shell/modules/sidebarRight/netmon/NetMonTab.qml"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.interfaces"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.publicIp"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.refreshPublicIp()"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.dnsLeak"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "RyokuNetMon.proxychain"
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" '"public"'
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" '"warning"'
assert_contains   "shell/modules/sidebarRight/netmon/NetMonTab.qml" "formatRate"

echo "ok: sidebar-netmon static asserts"
