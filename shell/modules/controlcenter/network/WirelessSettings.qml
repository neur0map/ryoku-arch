pragma ComponentBehavior: Bound

import "."
import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.services

ColumnLayout {
  id: root

  required property Session session

  spacing: Tokens.spacing.normal

  NetworkPanel {
    Layout.fillWidth: true
    icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
    title: qsTr("Wireless")
    subtitle: Nmcli.wifiEnabled ? qsTr("%1 nearby networks").arg(Nmcli.networks.length) : qsTr("Adapter disabled")

    NetworkSwitch {
      Layout.fillWidth: true
      icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
      title: qsTr("WiFi radio")
      subtitle: Nmcli.wifiEnabled ? qsTr("Enabled") : qsTr("Disabled")
      checked: Nmcli.wifiEnabled

      onToggled: checked => {
        Nmcli.enableWifi(checked);
      }
    }
  }

  NetworkPanel {
    Layout.fillWidth: true
    icon: "wifi_tethering"
    title: qsTr("Active WiFi")
    subtitle: Nmcli.active ? qsTr("Connected") : qsTr("Not connected")

    NetworkFact {
      Layout.fillWidth: true
      icon: "ssid_chart"
      label: qsTr("Network")
      value: Nmcli.active ? Nmcli.active.ssid : qsTr("Not connected")
      active: Nmcli.active !== null
    }

    NetworkFact {
      Layout.fillWidth: true
      icon: "signal_wifi_4_bar"
      label: qsTr("Signal")
      value: Nmcli.active ? qsTr("%1%").arg(Nmcli.active.strength) : qsTr("N/A")
      active: Nmcli.active !== null && Nmcli.active.strength > 50
    }

    NetworkFact {
      Layout.fillWidth: true
      icon: Nmcli.active && Nmcli.active.isSecure ? "lock" : "lock_open"
      label: qsTr("Security")
      value: Nmcli.active ? (Nmcli.active.isSecure ? qsTr("Secured") : qsTr("Open")) : qsTr("N/A")
      active: Nmcli.active !== null && Nmcli.active.isSecure
    }

    NetworkFact {
      Layout.fillWidth: true
      icon: "settings_input_antenna"
      label: qsTr("Frequency")
      value: Nmcli.active ? qsTr("%1 MHz").arg(Nmcli.active.frequency) : qsTr("N/A")
    }
  }
}
