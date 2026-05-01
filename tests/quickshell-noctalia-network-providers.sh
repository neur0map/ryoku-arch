#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

fail() {
  echo "FAIL: $1" >&2
  exit 1
}

runtime="config/quickshell/ryoku/Noctalia"
network_dir="$runtime/Services/Networking"

assert_no_secret_command_args() {
  local leaks

  if ! leaks="$(
    awk '
      function finish_array() {
        if (array_text ~ /(password|passphrase|psk|secret)/) {
          print FILENAME ":" array_start ": secret-like value in command argument array"
          found = 1
        }
        in_array = 0
        array_text = ""
      }

      {
        line = tolower($0)
        if (line ~ /(command|args|argv|arguments)[[:space:]]*[:=]/ && line ~ /(password|passphrase|psk|secret)/) {
          print FILENAME ":" FNR ": " $0
          found = 1
        }
        if (!in_array && line ~ /(command|args|argv|arguments)[[:space:]]*[:=][[:space:]]*\[/) {
          in_array = 1
          array_start = FNR
          array_text = line
          if (line ~ /\]/) finish_array()
          next
        }
        if (in_array) {
          array_text = array_text "\n" line
          if (line ~ /\]/) finish_array()
        }
      }

      END {
        exit found ? 1 : 0
      }
    ' "$network_dir"/*.qml
  )"; then
    printf '%s\n' "$leaks" >&2
    fail "Wi-Fi passwords should not be placed in command arguments"
  fi
}

[[ -f $network_dir/RyokuNetworkService.qml ]] \
  || fail "Ryoku network service should exist"
[[ -f $network_dir/IwdProvider.qml ]] \
  || fail "Ryoku network service should include an iwd provider"
[[ -f $network_dir/NmcliProvider.qml ]] \
  || fail "Ryoku network service should include an optional nmcli provider"

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
grep -Eq 'property bool (ready|usable)' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should expose readiness separately from command presence"
grep -Eq 'available:.*(ready|usable|stationDevice)' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should only be available when a usable station exists"
grep -q 'wifiPowered' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should track Wi-Fi powered state separately from station existence"
grep -q 'Powered' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should parse or query iwd powered state"
grep -q 'connect-hidden' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should support hidden-network connects"
! grep -q 'parts\.length >= 4' "$network_dir/IwdProvider.qml" \
  || fail "iwd provider should not treat non-station device rows as usable stations"
assert_no_secret_command_args

grep -q 'nmcli' "$network_dir/NmcliProvider.qml" \
  || fail "optional NetworkManager provider should use nmcli"
grep -Eq 'ryoku-cmd-present|commandExists|which|hasCommand' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should detect available providers"
grep -Eq 'iwd|IwdProvider' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should prefer iwd for Ryoku"
grep -Eq 'nmcli|NmcliProvider' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should fall back to nmcli only when present"
grep -q 'pendingScan' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should queue scan requests until a provider is available"
grep -Eq 'onAvailableChanged|providerChanged|availableChanged' "$network_dir/RyokuNetworkService.qml" \
  || fail "network service should flush queued scans when provider availability changes"

grep -q 'customIsHidden' "$runtime/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml" \
  || fail "Wi-Fi subtab should preserve hidden-network state"
grep -q 'customSsid, addNetworkPopup.customSecurityKey, addNetworkPopup.customPassword, addNetworkPopup.customIsHidden' "$runtime/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml" \
  || fail "hidden-network connects should pass the hidden flag to the Ryoku network service"
grep -A3 'id: miscSettingsBox' "$runtime/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml" | grep -q 'visible: false' \
  || fail "Wi-Fi subtab should hide airplane mode until the shared Bluetooth adapter exists"
if grep -A8 'if (effectivelyVisible)' "$runtime/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml" | grep -q 'if (RyokuNetworkService\.wifiEnabled.*RyokuNetworkService\.scan'; then
  fail "Wi-Fi subtab should request scans while visible even before provider detection completes"
fi

[[ -f $network_dir/RyokuBluetoothService.qml ]] \
  || fail "Ryoku Bluetooth service should exist"

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
grep -q 'id: scanProcess' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth scanning should use a dedicated bounded process"
grep -q 'id: scanOffProcess' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth scan stop should not wait behind the action queue"
grep -q -- '--timeout' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth scan and pair commands should be bounded"
! grep -q 'queueBluetoothctl(\["scan"' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth scan commands should not run through the serialized action queue"
! awk '
  /function connectDeviceWithTrust/ { in_fn = 1 }
  in_fn && /queueBluetoothctl\(\["trust"/ { found = 1 }
  in_fn && /^  function / && !/function connectDeviceWithTrust/ { in_fn = 0 }
  END { exit found ? 0 : 1 }
' "$network_dir/RyokuBluetoothService.qml" \
  || fail "Bluetooth connect should not implicitly persist device trust"
grep -q 'readonly property bool advancedBluetoothControlsSupported: false' "$runtime/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml" \
  || fail "Bluetooth subtab should mark unsupported advanced controls disabled"
grep -A5 'bluetooth-auto-connect-label' "$runtime/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml" | grep -q 'enabled: root.advancedBluetoothControlsSupported' \
  || fail "Global Bluetooth auto-connect control should be disabled for Ryoku"
grep -A8 'common.auto-connect' "$runtime/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml" | grep -q 'enabled: root.advancedBluetoothControlsSupported' \
  || fail "Per-device Bluetooth auto-connect control should be disabled for Ryoku"
grep -A5 'bluetooth-rssi-polling-label' "$runtime/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml" | grep -q 'enabled: root.advancedBluetoothControlsSupported' \
  || fail "Bluetooth RSSI polling control should be disabled for Ryoku"

grep -q 'RyokuNetworkService' "$runtime/Modules/Panels/Settings/Tabs/Connections/WifiSubTab.qml" \
  || fail "Wi-Fi subtab should use the Ryoku network service"
grep -q 'RyokuBluetoothService' "$runtime/Modules/Panels/Settings/Tabs/Connections/BluetoothSubTab.qml" \
  || fail "Bluetooth subtab should use the Ryoku Bluetooth service"
