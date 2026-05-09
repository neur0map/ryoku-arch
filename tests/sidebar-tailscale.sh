#!/bin/bash

# Static asserts for the Tailscale + Trayscale integration. Mirrors the
# style of tests/sidebar-openvpn.sh and tests/bar-secpulse.sh. Spec:
# docs/superpowers/specs/2026-05-08-tailscale-trayscale-integration-design.md.

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

assert_matches() {
  local path="$1"
  local re="$2"
  assert_file "$path"
  grep -qE "$re" "$ROOT_DIR/$path" || fail "$path should match regex: $re"
}

# 1. Service singleton + qmldir registration.
assert_file       "shell/services/RyokuTailscale.qml"
assert_contains   "shell/services/qmldir" "singleton RyokuTailscale 1.0 RyokuTailscale.qml"
assert_contains   "shell/services/RyokuTailscale.qml" "tailscale status --json"
assert_contains   "shell/services/RyokuTailscale.qml" "BackendState"
assert_contains   "shell/services/RyokuTailscale.qml" "Self?.HostName"
assert_contains   "shell/services/RyokuTailscale.qml" "function openTrayscale"
assert_matches    "shell/services/RyokuTailscale.qml" 'property bool tabOpen'

# 1b. AUR package list ships trayscale so fresh installs have the GUI
#     the openTrayscale() action launches.
assert_matches    "install/ryoku-aur.packages" '^trayscale$'

# 2. Both sidebar layouts drive RyokuTailscale.tabOpen in parallel with
#    the existing RyokuOpenVpn.tabOpen Binding.
assert_contains   "shell/modules/sidebarRight/BottomWidgetGroup.qml" "target: RyokuTailscale"
assert_contains   "shell/modules/sidebarRight/CompactSidebarRightContent.qml" "target: RyokuTailscale"


# 3. Sidebar status card exists and binds to RyokuTailscale state, with
#    an Open Trayscale action that calls openTrayscale().
assert_file       "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.connected"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.hostname"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.openTrayscale()"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" '"lan"'
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" 'buttonText: "Open Trayscale"'

# 4. OpenVpnTab instantiates TailscaleStatusCard and renders a Tailscale
#    not-installed stub gated on RyokuTailscale.installed.
assert_contains   "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml" "TailscaleStatusCard {"
assert_contains   "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml" "RyokuTailscale.installed"
assert_contains   "shell/modules/sidebarRight/openvpn/OpenVpnTab.qml" "Tailscale not installed"

# 5. Service exposes connect/disconnect actions; sidebar card wires them
#    in the Connect/Disconnect button and exposes IP click-to-copy.
assert_contains   "shell/services/RyokuTailscale.qml" "function connect"
assert_contains   "shell/services/RyokuTailscale.qml" "function disconnect"
assert_contains   "shell/services/RyokuTailscale.qml" 'execDetached(["tailscale", "up"])'
assert_contains   "shell/services/RyokuTailscale.qml" 'execDetached(["tailscale", "down"])'
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.disconnect()"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "RyokuTailscale.connect()"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" "Quickshell.clipboardText = RyokuTailscale.tailIp"
assert_contains   "shell/modules/sidebarRight/openvpn/TailscaleStatusCard.qml" '"content_copy"'

# 6. Install script sets the Tailscale operator so non-sudo control works.
assert_contains   "install/config/tailscale.sh" 'tailscale set --operator='

echo "ok: sidebar-tailscale static asserts"
