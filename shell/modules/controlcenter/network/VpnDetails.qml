pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.components.effects
import qs.services
import qs.utils

DeviceDetails {
  id: root

  required property Session session
  readonly property var vpnProvider: root.session.vpn.active
  readonly property bool providerEnabled: {
    if (!vpnProvider || vpnProvider.index === undefined)
      return false;
    const provider = GlobalConfig.utilities.vpn.provider[vpnProvider.index];
    return provider && typeof provider === "object" && provider.enabled === true;
  }

  function vpnStatusLabel() {
    if (!root.providerEnabled)
      return qsTr("Disabled");
    if (VPN.connecting)
      return qsTr("Connecting...");

    switch (VPN.status.state) {
    case "connected":
      return qsTr("Connected");
    case "disconnected":
      return qsTr("Disconnected");
    case "connecting":
      return qsTr("Connecting...");
    case "needs-auth":
      return qsTr("Authentication required");
    case "error":
      return qsTr("Error");
    default:
      return qsTr("Unknown");
    }
  }

  function providerCopy(provider, enabled) {
    if (typeof provider !== "object")
      return provider;

    const nextProvider = {
      name: provider.name,
      displayName: provider.displayName,
      interface: provider.interface,
      enabled: enabled
    };
    if (provider.connectCmd && provider.connectCmd.length > 0)
      nextProvider.connectCmd = provider.connectCmd;
    if (provider.disconnectCmd && provider.disconnectCmd.length > 0)
      nextProvider.disconnectCmd = provider.disconnectCmd;

    return nextProvider;
  }

  device: vpnProvider

  headerComponent: Component {
    ConnectionHeader {
      icon: "vpn_key"
      title: root.vpnProvider?.displayName ?? qsTr("Unknown")
    }
  }

  sections: [
    Component {
      NetworkPanel {
        icon: root.providerEnabled ? "vpn_key" : "vpn_key_off"
        title: qsTr("VPN provider")
        subtitle: root.vpnStatusLabel()

        NetworkSwitch {
          Layout.fillWidth: true
          icon: root.providerEnabled ? "vpn_key" : "vpn_key_off"
          title: qsTr("Enable provider")
          subtitle: root.providerEnabled ? qsTr("Selected for VPN actions") : qsTr("Disabled")
          checked: root.providerEnabled

          onToggled: checked => {
            if (!root.vpnProvider)
              return;
            const providers = [];
            const index = root.vpnProvider.index;

            for (let i = 0; i < GlobalConfig.utilities.vpn.provider.length; i++) {
              const p = GlobalConfig.utilities.vpn.provider[i];
              if (typeof p === "object") {
                let enabled = p.enabled !== false;
                if (checked)
                  enabled = i === index;
                else if (i === index)
                  enabled = false;
                providers.push(root.providerCopy(p, enabled));
              } else {
                providers.push(p);
              }
            }

            GlobalConfig.utilities.vpn.provider = providers;
          }
        }

        GridLayout {
          Layout.fillWidth: true
          columns: width > 620 ? 3 : 1
          columnSpacing: Tokens.spacing.small
          rowSpacing: Tokens.spacing.small

          NetworkAction {
            Layout.fillWidth: true
            visible: root.providerEnabled
            enabled: !VPN.connecting
            icon: VPN.connected ? "vpn_key_off" : "vpn_key"
            title: VPN.connected ? qsTr("Disconnect") : qsTr("Connect")
            subtitle: VPN.connecting ? qsTr("Working") : qsTr("VPN tunnel")
            primary: true

            onClicked: {
              VPN.toggle();
            }
          }

          NetworkAction {
            Layout.fillWidth: true
            icon: "edit"
            title: qsTr("Edit")
            subtitle: qsTr("Provider fields")

            onClicked: {
              const provider = GlobalConfig.utilities.vpn.provider[root.vpnProvider.index];
              editVpnDialog.editIndex = root.vpnProvider.index;
              editVpnDialog.providerName = root.vpnProvider.name;
              editVpnDialog.displayName = root.vpnProvider.displayName;
              editVpnDialog.interfaceName = root.vpnProvider.interface;
              editVpnDialog.connectCmd = (provider && provider.connectCmd) ? provider.connectCmd.join(" ") : "";
              editVpnDialog.disconnectCmd = (provider && provider.disconnectCmd) ? provider.disconnectCmd.join(" ") : "";
              editVpnDialog.open();
            }
          }

          NetworkAction {
            Layout.fillWidth: true
            icon: "delete"
            title: qsTr("Delete")
            subtitle: qsTr("Remove provider")
            destructive: true

            onClicked: {
              const providers = [];
              for (let i = 0; i < GlobalConfig.utilities.vpn.provider.length; i++) {
                if (i !== root.vpnProvider.index) {
                  providers.push(GlobalConfig.utilities.vpn.provider[i]);
                }
              }
              GlobalConfig.utilities.vpn.provider = providers;
              root.session.vpn.active = null;
            }
          }
        }

        NetworkAction {
          Layout.fillWidth: true
          visible: root.providerEnabled && VPN.status.state === "needs-auth" && VPN.status.authUrl !== ""
          icon: "open_in_browser"
          title: qsTr("Open login page")
          subtitle: qsTr("Continue authentication")
          primary: true

          onClicked: {
            Qt.openUrlExternally(VPN.status.authUrl);
          }
        }

        StyledText {
          Layout.fillWidth: true
          visible: root.providerEnabled && VPN.status.state === "needs-auth" && VPN.status.authUrl === ""
          text: qsTr("Click Connect to generate an authentication URL")
          font.pointSize: Tokens.font.size.small
          color: Colours.palette.m3onSurfaceVariant
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
        }
      }
    },
    Component {
      NetworkPanel {
        icon: "badge"
        title: qsTr("Provider details")
        subtitle: qsTr("Identity, interface, and status")

        NetworkFact {
          Layout.fillWidth: true
          icon: "vpn_key"
          label: qsTr("Provider")
          value: root.vpnProvider?.name ?? qsTr("Unknown")
          active: root.providerEnabled
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: "label"
          label: qsTr("Display name")
          value: root.vpnProvider?.displayName ?? qsTr("Unknown")
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: "settings_ethernet"
          label: qsTr("Interface")
          value: root.vpnProvider?.interface || qsTr("N/A")
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: VPN.status.state === "connected" ? "verified" : "info"
          label: qsTr("Status")
          value: root.vpnStatusLabel()
          active: VPN.status.state === "connected"
        }

        NetworkFact {
          Layout.fillWidth: true
          visible: VPN.status.reason !== ""
          icon: "article"
          label: qsTr("Details")
          value: VPN.status.reason
        }

        NetworkFact {
          Layout.fillWidth: true
          icon: root.providerEnabled ? "toggle_on" : "toggle_off"
          label: qsTr("Enabled")
          value: root.providerEnabled ? qsTr("Yes") : qsTr("No")
          active: root.providerEnabled
        }
      }
    }
  ]

  Popup {
    id: editVpnDialog

    property int editIndex: -1
    property string providerName: ""
    property string displayName: ""
    property string interfaceName: ""
    property string connectCmd: ""
    property string disconnectCmd: ""

    function closeWithAnimation(): void {
      close();
    }

    parent: Overlay.overlay
    anchors.centerIn: parent
    width: Math.min(400, parent.width - Tokens.padding.large * 2)
    padding: Tokens.padding.large * 1.5

    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    opacity: 0
    scale: 0.7

    enter: Transition {
      Anim {
        property: "opacity"
        from: 0
        to: 1
        type: Anim.FastSpatial
      }
      Anim {
        property: "scale"
        from: 0.7
        to: 1
        type: Anim.FastSpatial
      }
    }

    exit: Transition {
      Anim {
        property: "opacity"
        from: 1
        to: 0
        type: Anim.FastSpatial
      }
      Anim {
        property: "scale"
        from: 1
        to: 0.7
        type: Anim.FastSpatial
      }
    }

    Overlay.modal: Rectangle {
      color: Qt.rgba(0, 0, 0, 0.4 * editVpnDialog.opacity)
    }

    background: StyledRect {
      color: Colours.palette.m3surfaceContainerHigh
      radius: Tokens.rounding.large

      Elevation {
        anchors.fill: parent
        radius: parent.radius
        level: 3
        z: -1
      }
    }

    contentItem: ColumnLayout {
      spacing: Tokens.spacing.normal

      StyledText {
        text: qsTr("Edit VPN Provider")
        font.pointSize: Tokens.font.size.large
        font.weight: 500
      }

      DialogField {
        Layout.fillWidth: true
        label: qsTr("Display name")
        text: editVpnDialog.displayName
        onEdited: text => editVpnDialog.displayName = text
      }

      DialogField {
        Layout.fillWidth: true
        label: qsTr("Interface")
        text: editVpnDialog.interfaceName
        onEdited: text => editVpnDialog.interfaceName = text
      }

      DialogField {
        Layout.fillWidth: true
        visible: editVpnDialog.connectCmd.length > 0
        label: qsTr("Connect command")
        text: editVpnDialog.connectCmd
        onEdited: text => editVpnDialog.connectCmd = text
      }

      DialogField {
        Layout.fillWidth: true
        visible: editVpnDialog.disconnectCmd.length > 0
        label: qsTr("Disconnect command")
        text: editVpnDialog.disconnectCmd
        onEdited: text => editVpnDialog.disconnectCmd = text
      }

      RowLayout {
        Layout.topMargin: Tokens.spacing.normal
        Layout.fillWidth: true
        spacing: Tokens.spacing.normal

        TextButton {
          Layout.fillWidth: true
          text: qsTr("Cancel")
          inactiveColour: Colours.tPalette.m3surfaceContainerHigh
          inactiveOnColour: Colours.palette.m3onSurface
          onClicked: editVpnDialog.closeWithAnimation()
        }

        TextButton {
          Layout.fillWidth: true
          text: qsTr("Save")
          enabled: editVpnDialog.interfaceName.length > 0
          inactiveColour: Colours.palette.m3primaryContainer
          inactiveOnColour: Colours.palette.m3onPrimaryContainer

          onClicked: {
            const providers = [];
            const oldProvider = GlobalConfig.utilities.vpn.provider[editVpnDialog.editIndex];
            const wasEnabled = typeof oldProvider === "object" ? (oldProvider.enabled !== false) : true;

            for (let i = 0; i < GlobalConfig.utilities.vpn.provider.length; i++) {
              if (i === editVpnDialog.editIndex) {
                const hasCommands = editVpnDialog.connectCmd.length > 0 && editVpnDialog.disconnectCmd.length > 0;
                const newProvider = {
                  displayName: editVpnDialog.displayName || editVpnDialog.interfaceName,
                  enabled: wasEnabled,
                  interface: editVpnDialog.interfaceName,
                  name: editVpnDialog.providerName
                };

                if (hasCommands) {
                  newProvider.connectCmd = editVpnDialog.connectCmd.split(" ").filter(s => s.length > 0);
                  newProvider.disconnectCmd = editVpnDialog.disconnectCmd.split(" ").filter(s => s.length > 0);
                }

                providers.push(newProvider);
              } else {
                const p = GlobalConfig.utilities.vpn.provider[i];
                const reconstructed = {
                  displayName: p.displayName,
                  enabled: p.enabled,
                  interface: p.interface,
                  name: p.name
                };
                if (p.connectCmd && p.connectCmd.length > 0) {
                  reconstructed.connectCmd = p.connectCmd;
                }
                if (p.disconnectCmd && p.disconnectCmd.length > 0) {
                  reconstructed.disconnectCmd = p.disconnectCmd;
                }
                providers.push(reconstructed);
              }
            }

            GlobalConfig.utilities.vpn.provider = providers;
            editVpnDialog.closeWithAnimation();
          }
        }
      }
    }
  }

  component DialogField: ColumnLayout {
    id: dialogField

    property string label
    property string text
    signal edited(string text)

    spacing: Tokens.spacing.smaller / 2

    StyledText {
      Layout.fillWidth: true
      text: dialogField.label
      font.pointSize: Tokens.font.size.small
      color: Colours.palette.m3onSurfaceVariant
      elide: Text.ElideRight
    }

    StyledRect {
      Layout.fillWidth: true
      implicitHeight: 40
      color: field.activeFocus ? Colours.layer(Colours.palette.m3surfaceContainer, 3) : Colours.layer(Colours.palette.m3surfaceContainer, 2)
      radius: Tokens.rounding.small
      border.width: 1
      border.color: field.activeFocus ? Colours.palette.m3primary : Qt.alpha(Colours.palette.m3outline, 0.3)

      Behavior on color {
        CAnim {}
      }
      Behavior on border.color {
        CAnim {}
      }

      StyledTextField {
        id: field

        anchors.centerIn: parent
        width: parent.width - Tokens.padding.normal
        horizontalAlignment: TextInput.AlignLeft
        text: dialogField.text
        onTextChanged: dialogField.edited(text)
      }
    }
  }
}
