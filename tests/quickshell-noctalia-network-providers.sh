#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

runtime="config/quickshell/ryoku/Noctalia"
network_dir="$runtime/Services/Networking"

[[ -f $network_dir/RyokuNetworkService.qml ]] \
  || fail "Ryoku network service should exist"
[[ -f $network_dir/IwdProvider.qml ]] \
  || fail "Ryoku network service should include an iwd provider"
[[ -f $network_dir/NmcliProvider.qml ]] \
  || fail "Ryoku network service should include an optional nmcli provider"
[[ -f $network_dir/RyokuBluetoothService.qml ]] \
  || fail "Ryoku Bluetooth service should exist"

grep -q 'iwctl' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should use iwctl"
grep -q 'station.*scan' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should support scanning"
grep -q 'station.*get-networks' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should support listing networks"
grep -q 'passphrase' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should support secured network connections"
grep -Eq 'stdin|write|input|process\.stdin' "$network_dir/IwdProvider.qml" \
  || fail "Wi-Fi secrets should be supplied through process input, not argv"
! rg -n 'iwctl.*(password|passphrase|psk|secret).*argv|command:.*(password|passphrase|psk|secret)' "$network_dir" \
  || fail "Wi-Fi passwords should not be placed in command arguments"

grep -q 'nmcli' "$network_dir/NmcliProvider.qml" \
  || fail "optional NetworkManager provider should use nmcli"
grep -Eq 'ryoku-cmd-present|commandExists|which|hasCommand' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should detect available providers"
grep -Eq 'iwd|IwdProvider' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should prefer iwd for Ryoku"
grep -Eq 'nmcli|NmcliProvider' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should fall back to nmcli only when present"

grep -q 'bluetoothctl' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should use bluetoothctl"
grep -q 'scan on' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support scanning"
grep -q 'pair' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support pairing"
grep -q 'connect' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support connecting"
grep -q 'trust' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth service should support trusted devices"

grep -q 'RyokuNetworkService' "$runtime/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml" \
  || fail "Wi-Fi subtab should use the Ryoku network service"
grep -q 'RyokuBluetoothService' "$runtime/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml" \
  || fail "Bluetooth subtab should use the Ryoku Bluetooth service"
