pragma ComponentBehavior: Bound

import "."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

ColumnLayout {
  id: root

  required property Session session

  spacing: Tokens.spacing.normal

  NetworkPanel {
    Layout.fillWidth: true
    icon: "router"
    title: qsTr("Network console")
    subtitle: Nmcli.active ? qsTr("%1 on WiFi").arg(Nmcli.active.ssid) : (Nmcli.activeEthernet ? qsTr("%1 on Ethernet").arg(Nmcli.activeEthernet.interface) : qsTr("No active connection"))

    GridLayout {
      Layout.fillWidth: true
      columns: width > 620 ? 2 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      NetworkFact {
        Layout.fillWidth: true
        icon: "cable"
        label: qsTr("Ethernet")
        value: qsTr("%1 total").arg(Nmcli.ethernetDevices.length)
        active: Nmcli.activeEthernet !== null
      }

      NetworkFact {
        Layout.fillWidth: true
        icon: "lan"
        label: qsTr("Connected")
        value: qsTr("%1 wired").arg(Nmcli.ethernetDevices.filter(d => d.connected).length)
        active: Nmcli.ethernetDevices.filter(d => d.connected).length > 0
      }
    }
  }

  NetworkPanel {
    Layout.fillWidth: true
    icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
    title: qsTr("Wireless radio")
    subtitle: Nmcli.wifiEnabled ? qsTr("Scanning and WiFi joins enabled") : qsTr("Wireless adapter disabled")

    NetworkSwitch {
      Layout.fillWidth: true
      icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
      title: qsTr("WiFi")
      subtitle: Nmcli.wifiEnabled ? qsTr("Enabled") : qsTr("Disabled")
      checked: Nmcli.wifiEnabled

      onToggled: checked => {
        Nmcli.enableWifi(checked);
      }
    }
  }

  NetworkPanel {
    Layout.fillWidth: true
    visible: GlobalConfig.utilities.vpn.enabled || GlobalConfig.utilities.vpn.provider.length > 0
    icon: "vpn_key"
    title: qsTr("VPN")
    subtitle: qsTr("%1 providers").arg(GlobalConfig.utilities.vpn.provider.length)

    NetworkSwitch {
      Layout.fillWidth: true
      icon: GlobalConfig.utilities.vpn.enabled ? "vpn_key" : "vpn_key_off"
      title: qsTr("VPN service")
      subtitle: GlobalConfig.utilities.vpn.enabled ? qsTr("Available in network controls") : qsTr("Hidden from network controls")
      checked: GlobalConfig.utilities.vpn.enabled

      onToggled: checked => {
        GlobalConfig.utilities.vpn.enabled = checked;
      }
    }

    NetworkFact {
      Layout.fillWidth: true
      icon: "format_list_numbered"
      label: qsTr("Providers")
      value: qsTr("%1").arg(GlobalConfig.utilities.vpn.provider.length)
      active: GlobalConfig.utilities.vpn.provider.length > 0
    }

    NetworkAction {
      Layout.fillWidth: true
      icon: "tune"
      title: qsTr("Manage providers")
      subtitle: qsTr("Order, add, or remove VPN entries")
      primary: true

      onClicked: {
        vpnSettingsDialog.open();
      }
    }
  }

  NetworkPanel {
    Layout.fillWidth: true
    icon: "hub"
    title: qsTr("Current connection")
    subtitle: qsTr("Live network details")

    NetworkFact {
      Layout.fillWidth: true
      icon: Nmcli.active ? "wifi" : (Nmcli.activeEthernet ? "cable" : "link_off")
      label: qsTr("Network")
      value: Nmcli.active ? Nmcli.active.ssid : (Nmcli.activeEthernet ? Nmcli.activeEthernet.interface : qsTr("Not connected"))
      active: Nmcli.active !== null || Nmcli.activeEthernet !== null
    }

    NetworkFact {
      Layout.fillWidth: true
      visible: Nmcli.active !== null
      icon: "signal_wifi_4_bar"
      label: qsTr("Signal")
      value: Nmcli.active ? qsTr("%1%").arg(Nmcli.active.strength) : qsTr("N/A")
      active: Nmcli.active !== null && Nmcli.active.strength > 50
    }

    NetworkFact {
      Layout.fillWidth: true
      visible: Nmcli.active !== null
      icon: Nmcli.active && Nmcli.active.isSecure ? "lock" : "lock_open"
      label: qsTr("Security")
      value: Nmcli.active ? (Nmcli.active.isSecure ? qsTr("Secured") : qsTr("Open")) : qsTr("N/A")
      active: Nmcli.active !== null && Nmcli.active.isSecure
    }

    NetworkFact {
      Layout.fillWidth: true
      visible: Nmcli.active !== null
      icon: "settings_input_antenna"
      label: qsTr("Frequency")
      value: Nmcli.active ? qsTr("%1 MHz").arg(Nmcli.active.frequency) : qsTr("N/A")
    }
  }

  Popup {
    id: vpnSettingsDialog

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(600, parent.width - Tokens.padding.large * 2)
    height: Math.min(700, parent.height - Tokens.padding.large * 2)

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    background: StyledRect {
      color: Colours.palette.m3surface
      radius: Tokens.rounding.large
    }

    StyledFlickable {
      anchors.fill: parent
      anchors.margins: Tokens.padding.large * 1.5
      flickableDirection: Flickable.VerticalFlick
      contentHeight: vpnSettingsContent.height
      clip: true

      VpnSettings {
        id: vpnSettingsContent

        anchors.left: parent.left
        anchors.right: parent.right
        session: root.session
      }
    }
  }
}
