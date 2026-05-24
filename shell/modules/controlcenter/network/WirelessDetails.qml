pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import QtQuick
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.utils

DeviceDetails {
  id: root

  required property Session session
  readonly property var network: root.session.network.active

  function checkSavedProfile(): void {
    if (network && network.ssid) {
      Nmcli.loadSavedConnections(() => {});
    }
  }

  function updateDeviceDetails(): void {
    if (network && network.ssid) {
      const isActive = network.active || (Nmcli.active && Nmcli.active.ssid === network.ssid);
      if (isActive) {
        Nmcli.getWirelessDeviceDetails("");
      } else {
        Nmcli.wirelessDeviceDetails = null;
      }
    } else {
      Nmcli.wirelessDeviceDetails = null;
    }
  }

  device: network

  Component.onCompleted: {
    updateDeviceDetails();
    checkSavedProfile();
  }

  onNetworkChanged: {
    connectionUpdateTimer.stop();
    if (network && network.ssid) {
      connectionUpdateTimer.start();
    }
    updateDeviceDetails();
    checkSavedProfile();
  }

  headerComponent: Component {
    ConnectionHeader {
      icon: root.network?.isSecure ? "lock" : "wifi"
      title: root.network?.ssid ?? qsTr("Unknown")
    }
  }

  sections: [
    Component {
      NetworkPanel {
        icon: root.network?.active ? "wifi" : "wifi_find"
        title: qsTr("Wireless link")
        subtitle: root.network?.active ? qsTr("Connected") : qsTr("Available network")

        NetworkSwitch {
          Layout.fillWidth: true
          icon: root.network?.active ? "wifi" : "wifi_off"
          title: qsTr("Connection")
          subtitle: root.network?.active ? qsTr("Connected") : qsTr("Disconnected")
          checked: root.network?.active ?? false

          onToggled: checked => {
            if (checked) {
              NetworkConnection.handleConnect(root.network, root.session, null);
            } else {
              Nmcli.disconnectFromNetwork();
            }
          }
        }

        NetworkAction {
          Layout.fillWidth: true
          visible: {
            if (!root.network || !root.network.ssid)
              return false;
            return Nmcli.hasSavedProfile(root.network.ssid);
          }
          icon: "delete"
          title: qsTr("Forget network")
          subtitle: qsTr("Remove saved profile")
          destructive: true

          onClicked: {
            if (root.network && root.network.ssid) {
              if (root.network.active) {
                Nmcli.disconnectFromNetwork();
              }
              Nmcli.forgetNetwork(root.network.ssid);
            }
          }
        }
      }
    },
    Component {
      NetworkPanel {
        icon: "ssid_chart"
        title: qsTr("Network properties")
        subtitle: qsTr("SSID, signal, and radio details")

        NetworkFact {
          Layout.fillWidth: true
          icon: "wifi"
          label: qsTr("SSID")
          value: root.network?.ssid ?? qsTr("Unknown")
          active: root.network?.active ?? false
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: "fingerprint"
          label: qsTr("BSSID")
          value: root.network?.bssid ?? qsTr("Unknown")
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: "signal_wifi_4_bar"
          label: qsTr("Signal")
          value: root.network ? qsTr("%1%").arg(root.network.strength) : qsTr("N/A")
          active: root.network && root.network.strength > 50
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: "settings_input_antenna"
          label: qsTr("Frequency")
          value: root.network ? qsTr("%1 MHz").arg(root.network.frequency) : qsTr("N/A")
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: root.network && root.network.isSecure ? "lock" : "lock_open"
          label: qsTr("Security")
          value: root.network ? (root.network.isSecure ? root.network.security : qsTr("Open")) : qsTr("N/A")
          active: root.network && root.network.isSecure
        }
      }
    },
    Component {
      NetworkPanel {
        icon: "lan"
        title: qsTr("Connection information")
        subtitle: qsTr("Runtime IP and route data")

        ConnectionInfoSection {
          deviceDetails: Nmcli.wirelessDeviceDetails
        }
      }
    }
  ]

  Connections {
    function onActiveChanged() {
      updateDeviceDetails();
    }
    function onWirelessDeviceDetailsChanged() {
      if (network && network.ssid) {
        const isActive = network.active || (Nmcli.active && Nmcli.active.ssid === network.ssid);
        if (isActive && Nmcli.wirelessDeviceDetails && Nmcli.wirelessDeviceDetails !== null) {
          connectionUpdateTimer.stop();
        }
      }
    }

    target: Nmcli
  }

  Timer {
    id: connectionUpdateTimer

    interval: 500
    repeat: true
    running: network && network.ssid
    onTriggered: {
      if (network) {
        const isActive = network.active || (Nmcli.active && Nmcli.active.ssid === network.ssid);
        if (isActive) {
          if (!Nmcli.wirelessDeviceDetails || Nmcli.wirelessDeviceDetails === null) {
            Nmcli.getWirelessDeviceDetails("", () => {});
          } else {
            connectionUpdateTimer.stop();
          }
        } else {
          if (Nmcli.wirelessDeviceDetails !== null) {
            Nmcli.wirelessDeviceDetails = null;
          }
        }
      }
    }
  }
}
