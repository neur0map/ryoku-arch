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
assert_contains "component NetworkServiceDock: NetworkCard" \
  "Network settings should fill the right side with service/device controls instead of blank space"
assert_contains "subtitle: qsTr(\"Quick service controls\")" \
  "Network services dock should prioritize controls instead of duplicate metrics"
assert_not_contains "subtitle: qsTr(\"VPN and wired adapters\")" \
  "Network services dock should not keep the older bulky service summary"
assert_contains "component NetworkConnectorGrid: ColumnLayout" \
  "Network settings should replace clipped service lists with compact connector chips"
assert_contains "visible: GlobalConfig.utilities.vpn.provider.length > 0 || Nmcli.ethernetDevices.length > 0" \
  "Network connector area should disappear when there are no connectors to show"
assert_contains "component NetworkConnectorChip: StyledRect" \
  "Network settings should expose compact VPN and ethernet connector chips"
assert_contains "component NetworkInventoryPanel: ColumnLayout" \
  "Network settings should keep the full VPN and ethernet inventory outside the cramped service dock"
assert_contains "component NetworkDetailsDock: NetworkCard" \
  "Network details should be a compact dock, not a full-width deadspace block"
assert_contains "component MetricTile: StyledRect" \
  "Network settings should show compact metric tiles instead of long rows"
assert_contains "component QuickToggleRow: StyledRect" \
  "Network settings should use compact toggle rows instead of full-width toggle bands"
assert_contains "readonly property bool compact:" \
  "Network settings should adapt the grid at narrower widths"
assert_contains "readonly property bool compact: width < 620" \
  "Network settings should keep multi-column content in the compact settings window"
assert_contains "columns: root.compact ? 1 : 5" \
  "Network settings should use a five-column workbench at the compact window size"
assert_contains "Layout.columnSpan: root.compact ? 1 : 2" \
  "Network overview should be a compact left board, not a half-page block"
assert_contains "Layout.columnSpan: root.compact ? 1 : 3" \
  "Network lists and controls should fill the remaining workbench columns"
assert_contains "columns: width > 360 ? 2 : 1" \
  "Network quick actions should stay as compact tiles instead of one-column full-width rows"
assert_not_contains "width < 1080" \
  "Network settings should not treat the compact window as a forced one-column layout"
assert_not_contains "columns: root.compact ? 1 : 2" \
  "Network settings should not collapse quick actions into long single-column bands"
assert_not_contains "implicitHeight: 56" \
  "Network metric tiles should not keep the tall generic card height"
assert_not_contains "implicitHeight: 48" \
  "Network quick rows should not keep the old bulky height"
assert_not_contains "Layout.columnSpan: 12" \
  "Network settings should not keep full-width detail bands that create deadspace"
assert_contains "root.session.vpn.active = chip.modelData" \
  "Network connector chips should preserve VPN selection behavior"
assert_contains "root.session.ethernet.active = chip.modelData" \
  "Network connector chips should preserve ethernet selection behavior"

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
