pragma ComponentBehavior: Bound

import "."
import QtQuick
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.services

ColumnLayout {
  id: root

  required property Session session

  function providerRows() {
    return GlobalConfig.utilities.vpn.provider.map((provider, index) => {
      const isObject = typeof provider === "object";
      const name = isObject ? (provider.name || "custom") : String(provider);
      const displayName = isObject ? (provider.displayName || name) : name;
      const iface = isObject ? (provider.interface || "") : "";

      return {
        index: index,
        name: name,
        displayName: displayName,
        interface: iface,
        provider: provider,
        isActive: index === 0
      };
    });
  }

  function cloneProvider(provider) {
    if (typeof provider !== "object")
      return provider;

    const reconstructed = {
      name: provider.name,
      displayName: provider.displayName,
      interface: provider.interface,
      enabled: provider.enabled
    };
    if (provider.connectCmd && provider.connectCmd.length > 0)
      reconstructed.connectCmd = provider.connectCmd;
    if (provider.disconnectCmd && provider.disconnectCmd.length > 0)
      reconstructed.disconnectCmd = provider.disconnectCmd;

    return reconstructed;
  }

  function clonedProviders() {
    const providers = [];
    for (let i = 0; i < GlobalConfig.utilities.vpn.provider.length; i++) {
      providers.push(root.cloneProvider(GlobalConfig.utilities.vpn.provider[i]));
    }
    return providers;
  }

  function addProvider(name, displayName, iface) {
    const providers = [...GlobalConfig.utilities.vpn.provider];
    providers.push({
      name: name,
      displayName: displayName,
      interface: iface
    });
    GlobalConfig.utilities.vpn.provider = providers;
  }

  spacing: Tokens.spacing.normal

  NetworkPanel {
    Layout.fillWidth: true
    icon: GlobalConfig.utilities.vpn.enabled ? "vpn_key" : "vpn_key_off"
    title: qsTr("VPN service")
    subtitle: GlobalConfig.utilities.vpn.enabled ? qsTr("Visible in network controls") : qsTr("Provider controls hidden")

    NetworkSwitch {
      Layout.fillWidth: true
      icon: GlobalConfig.utilities.vpn.enabled ? "vpn_key" : "vpn_key_off"
      title: qsTr("VPN")
      subtitle: GlobalConfig.utilities.vpn.enabled ? qsTr("Enabled") : qsTr("Disabled")
      checked: GlobalConfig.utilities.vpn.enabled

      onToggled: checked => {
        GlobalConfig.utilities.vpn.enabled = checked;
      }
    }
  }

  NetworkPanel {
    Layout.fillWidth: true
    icon: "dns"
    title: qsTr("Providers")
    subtitle: qsTr("%1 configured").arg(GlobalConfig.utilities.vpn.provider.length)

    ListView {
      Layout.fillWidth: true
      Layout.preferredHeight: Math.max(contentHeight, GlobalConfig.utilities.vpn.provider.length === 0 ? 50 : 0)
      interactive: false
      spacing: Tokens.spacing.smaller
      model: ScriptModel {
        values: root.providerRows()
      }

      delegate: ProviderCard {
        width: ListView.view ? ListView.view.width : 0
      }
    }

    StyledText {
      Layout.fillWidth: true
      visible: GlobalConfig.utilities.vpn.provider.length === 0
      text: qsTr("No VPN providers configured")
      color: Colours.palette.m3onSurfaceVariant
      horizontalAlignment: Text.AlignHCenter
      font.pointSize: Tokens.font.size.small
      elide: Text.ElideRight
    }
  }

  NetworkPanel {
    Layout.fillWidth: true
    icon: "add_link"
    title: qsTr("Quick add")
    subtitle: qsTr("Common VPN interfaces")

    GridLayout {
      Layout.fillWidth: true
      columns: width > 620 ? 3 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      NetworkAction {
        Layout.fillWidth: true
        icon: "add"
        title: qsTr("NetBird")
        subtitle: "wt0"

        onClicked: {
          root.addProvider("netbird", "NetBird", "wt0");
        }
      }

      NetworkAction {
        Layout.fillWidth: true
        icon: "add"
        title: qsTr("Tailscale")
        subtitle: "tailscale0"

        onClicked: {
          root.addProvider("tailscale", "Tailscale", "tailscale0");
        }
      }

      NetworkAction {
        Layout.fillWidth: true
        icon: "add"
        title: qsTr("Cloudflare")
        subtitle: "CloudflareWARP"

        onClicked: {
          root.addProvider("warp", "Cloudflare WARP", "CloudflareWARP");
        }
      }
    }
  }

  component ProviderCard: StyledRect {
    id: providerCard

    required property var modelData
    required property int index

    implicitHeight: 58
    radius: Tokens.rounding.small
    color: modelData.isActive ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainerHigh
    clip: true

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Tokens.padding.normal
      anchors.rightMargin: Tokens.padding.small
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: modelData.isActive ? "vpn_key" : "vpn_key_off"
        color: modelData.isActive ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        fill: modelData.isActive ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: modelData.displayName
          color: modelData.isActive ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
          font.weight: modelData.isActive ? 700 : 600
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: qsTr("%1 / %2").arg(modelData.name).arg(modelData.interface || qsTr("No interface"))
          color: modelData.isActive ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
          opacity: modelData.isActive ? 0.78 : 1
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }

      IconButton {
        Layout.alignment: Qt.AlignVCenter
        icon: modelData.isActive ? "arrow_downward" : "arrow_upward"
        visible: !modelData.isActive || GlobalConfig.utilities.vpn.provider.length > 1

        onClicked: {
          const providers = root.clonedProviders();
          if (modelData.isActive && index < providers.length - 1) {
            const temp = providers[index];
            providers[index] = providers[index + 1];
            providers[index + 1] = temp;
          } else if (!modelData.isActive) {
            const provider = providers.splice(index, 1)[0];
            providers.unshift(provider);
          }

          GlobalConfig.utilities.vpn.provider = providers;
        }
      }

      IconButton {
        Layout.alignment: Qt.AlignVCenter
        icon: "delete"

        onClicked: {
          const providers = [];
          for (let i = 0; i < GlobalConfig.utilities.vpn.provider.length; i++) {
            if (i !== index)
              providers.push(root.cloneProvider(GlobalConfig.utilities.vpn.provider[i]));
          }
          GlobalConfig.utilities.vpn.provider = providers;
        }
      }
    }
  }
}
