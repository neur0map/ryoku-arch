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

DeviceDetails {
  id: root

  required property Session session
  readonly property var ethernetDevice: root.session.ethernet.active

  device: ethernetDevice

  Component.onCompleted: {
    if (ethernetDevice && ethernetDevice.interface) {
      Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
    }
  }

  onEthernetDeviceChanged: {
    if (ethernetDevice && ethernetDevice.interface) {
      Nmcli.getEthernetDeviceDetails(ethernetDevice.interface, () => {});
    } else {
      Nmcli.ethernetDeviceDetails = null;
    }
  }

  headerComponent: Component {
    ConnectionHeader {
      icon: "cable"
      title: root.ethernetDevice?.interface ?? qsTr("Unknown")
    }
  }

  sections: [
    Component {
      NetworkPanel {
        icon: root.ethernetDevice?.connected ? "settings_ethernet" : "cable"
        title: qsTr("Ethernet link")
        subtitle: root.ethernetDevice?.connected ? qsTr("Connected") : qsTr("Disconnected")

        NetworkSwitch {
          Layout.fillWidth: true
          icon: root.ethernetDevice?.connected ? "settings_ethernet" : "link_off"
          title: qsTr("Connection")
          subtitle: root.ethernetDevice?.connection || qsTr("No profile")
          checked: root.ethernetDevice?.connected ?? false

          onToggled: checked => {
            if (checked) {
              Nmcli.connectEthernet(root.ethernetDevice?.connection || "", root.ethernetDevice?.interface || "", () => {});
            } else {
              if (root.ethernetDevice?.connection) {
                Nmcli.disconnectEthernet(root.ethernetDevice.connection, () => {});
              }
            }
          }
        }
      }
    },
    Component {
      NetworkPanel {
        icon: "badge"
        title: qsTr("Device properties")
        subtitle: qsTr("Interface and profile state")

        NetworkFact {
          Layout.fillWidth: true
          icon: "settings_ethernet"
          label: qsTr("Interface")
          value: root.ethernetDevice?.interface ?? qsTr("Unknown")
          active: root.ethernetDevice?.connected ?? false
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: "lan"
          label: qsTr("Connection")
          value: root.ethernetDevice?.connection || qsTr("Not connected")
          active: root.ethernetDevice?.connection !== ""
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: "info"
          label: qsTr("State")
          value: root.ethernetDevice?.state ?? qsTr("Unknown")
          active: root.ethernetDevice?.connected ?? false
        }
      }
    },
    Component {
      NetworkPanel {
        icon: "lan"
        title: qsTr("Connection information")
        subtitle: qsTr("Runtime IP and route data")

        ConnectionInfoSection {
          deviceDetails: Nmcli.ethernetDeviceDetails
        }
      }
    }
  ]
}
