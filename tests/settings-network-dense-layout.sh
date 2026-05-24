#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
NETWORK_PANE="$ROOT_DIR/shell/modules/controlcenter/network/NetworkingPane.qml"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local needle="$1"
  local message="$2"

  grep -Fq "$needle" "$NETWORK_PANE" || fail "$message"
}

assert_not_contains() {
  local needle="$1"
  local message="$2"

  ! grep -Fq "$needle" "$NETWORK_PANE" || fail "$message"
}

[[ -f $NETWORK_PANE ]] || fail "missing NetworkingPane.qml"

assert_not_contains "SplitPaneLayout" \
  "Network settings should not keep the old split-pane layout"
assert_not_contains "CollapsibleSection" \
  "Network settings should not use long collapsible bands for compact lists"
assert_not_contains "NetworkSettings {" \
  "Network settings default view should not be the old full-width section stack"

assert_contains "GridLayout {" \
  "Network settings should arrange content in a dense grid"
assert_contains "component NetworkCard: StyledRect" \
  "Network settings should use compact reusable cards"
assert_contains "component MetricTile: StyledRect" \
  "Network settings should show compact metric tiles instead of long rows"
assert_contains "component QuickToggleRow: StyledRect" \
  "Network settings should use compact toggle rows instead of full-width toggle bands"
assert_contains "readonly property bool compact:" \
  "Network settings should adapt the grid at narrower widths"

assert_contains "Nmcli.toggleWifi(null)" \
  "Network settings should preserve WiFi toggle behavior"
assert_contains "Nmcli.rescanWifi()" \
  "Network settings should preserve WiFi scan behavior"
assert_contains "Nmcli.enableWifi(checked)" \
  "Network settings should preserve explicit WiFi enabled setting behavior"
assert_contains "GlobalConfig.utilities.vpn.enabled = checked" \
  "Network settings should preserve VPN enabled behavior"
assert_contains "root.session.vpn.active" \
  "Network settings should preserve VPN selection state"
assert_contains "root.session.ethernet.active" \
  "Network settings should preserve ethernet selection state"
assert_contains "root.session.network.active" \
  "Network settings should preserve wireless selection state"
assert_contains "WirelessPasswordDialog" \
  "Network settings should preserve wireless password dialog behavior"

echo "PASS: settings network dense layout"
