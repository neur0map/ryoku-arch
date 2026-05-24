#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

assert_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

assert_not_contains() {
  local file="$1"
  local needle="$2"
  local message="$3"

  ! grep -Fq "$needle" "$ROOT_DIR/$file" || fail "$message"
}

network_files=(
  "shell/modules/controlcenter/network/NetworkSettings.qml"
  "shell/modules/controlcenter/network/WirelessSettings.qml"
  "shell/modules/controlcenter/network/VpnSettings.qml"
  "shell/modules/controlcenter/network/WirelessDetails.qml"
  "shell/modules/controlcenter/network/EthernetDetails.qml"
  "shell/modules/controlcenter/network/VpnDetails.qml"
)

for file in "${network_files[@]}"; do
  assert_not_contains "$file" "SectionContainer" \
    "$file should not keep generic section containers"
  assert_not_contains "$file" "SectionHeader" \
    "$file should not keep generic section headers"
  assert_not_contains "$file" "ToggleRow" \
    "$file should not keep generic toggle rows"
  assert_not_contains "$file" "PropertyRow" \
    "$file should not keep generic property rows"
done

assert_contains "shell/modules/controlcenter/network/NetworkPanel.qml" "id: networkPanelRoot" \
  "network subpanes should use network-specific panels"
assert_contains "shell/modules/controlcenter/network/NetworkFact.qml" "id: networkFactRoot" \
  "network subpanes should use compact network facts"
assert_contains "shell/modules/controlcenter/network/NetworkSwitch.qml" "id: networkSwitchRoot" \
  "network subpanes should use compact network toggles"
assert_contains "shell/modules/controlcenter/network/NetworkAction.qml" "id: networkActionRoot" \
  "network subpanes should use compact network actions"

assert_contains "shell/modules/controlcenter/network/NetworkSettings.qml" "Nmcli.enableWifi(checked)" \
  "network settings should preserve WiFi backend"
assert_contains "shell/modules/controlcenter/network/WirelessSettings.qml" "Nmcli.enableWifi(checked)" \
  "wireless settings should preserve WiFi backend"
assert_contains "shell/modules/controlcenter/network/WirelessDetails.qml" "NetworkConnection.handleConnect(root.network, root.session, null)" \
  "wireless details should preserve connect backend"
assert_contains "shell/modules/controlcenter/network/WirelessDetails.qml" "Nmcli.disconnectFromNetwork()" \
  "wireless details should preserve disconnect backend"
assert_contains "shell/modules/controlcenter/network/WirelessDetails.qml" "Nmcli.forgetNetwork(root.network.ssid)" \
  "wireless details should preserve forget backend"
assert_contains "shell/modules/controlcenter/network/EthernetDetails.qml" "Nmcli.connectEthernet(root.ethernetDevice?.connection || \"\", root.ethernetDevice?.interface || \"\", () => {})" \
  "ethernet details should preserve connect backend"
assert_contains "shell/modules/controlcenter/network/EthernetDetails.qml" "Nmcli.disconnectEthernet(root.ethernetDevice.connection, () => {})" \
  "ethernet details should preserve disconnect backend"
assert_contains "shell/modules/controlcenter/network/VpnSettings.qml" "GlobalConfig.utilities.vpn.provider = providers" \
  "vpn settings should preserve provider backend writes"
assert_contains "shell/modules/controlcenter/network/VpnDetails.qml" "VPN.toggle()" \
  "vpn details should preserve connect toggle backend"
assert_contains "shell/modules/controlcenter/network/VpnDetails.qml" "GlobalConfig.utilities.vpn.provider = providers" \
  "vpn details should preserve provider backend writes"

echo "PASS: tests/settings-network-subpanes-remake.sh"
