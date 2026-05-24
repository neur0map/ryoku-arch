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
import qs.components.effects
import qs.services

Item {
  id: root

  required property Session session

  readonly property bool compact: width < 620
  readonly property bool medium: width < 900
  readonly property var activeVpn: session && session.vpn ? session.vpn.active : null
  readonly property var activeEthernet: session && session.ethernet ? session.ethernet.active : null
  readonly property var activeWireless: session && session.network ? session.network.active : null
  property string paneId: activeVpn ? ("vpn:" + (activeVpn.name || activeVpn.displayName || "")) : (activeEthernet ? ("eth:" + (activeEthernet.interface || "")) : (activeWireless ? ("wifi:" + (activeWireless.ssid || activeWireless.bssid || "")) : "overview"))

  function clearSelection(): void {
    if (root.session.vpn)
      root.session.vpn.active = null;
    if (root.session.ethernet)
      root.session.ethernet.active = null;
    if (root.session.network)
      root.session.network.active = null;
  }

  function selectedTitle(): string {
    if (activeVpn)
      return activeVpn.displayName || activeVpn.name || qsTr("VPN");
    if (activeEthernet)
      return activeEthernet.interface || qsTr("Ethernet");
    if (activeWireless)
      return activeWireless.ssid || qsTr("Wireless");
    return qsTr("Connection overview");
  }

  function selectedIcon(): string {
    if (activeVpn)
      return VPN.connected ? "vpn_key" : "vpn_key_off";
    if (activeEthernet)
      return "cable";
    if (activeWireless)
      return "wifi";
    return "router";
  }

  function detailsComponent(): Component {
    if (activeVpn)
      return vpnDetailsComponent;
    if (activeEthernet)
      return ethernetDetailsComponent;
    if (activeWireless)
      return wirelessDetailsComponent;
    return overviewDetailsComponent;
  }

  onPaneIdChanged: {
    detailsHost.nextComponent = root.detailsComponent();
  }

  Behavior on paneId {
    PaneTransition {
      target: detailsLoader
      propertyActions: [
        PropertyAction {
          target: detailsHost
          property: "targetComponent"
          value: detailsHost.nextComponent
        }
      ]
    }
  }

  anchors.fill: parent

  Connections {
    function onActiveChanged(): void {
      if (root.session.vpn && root.session.vpn.active) {
        if (root.session.ethernet)
          root.session.ethernet.active = null;
        if (root.session.network)
          root.session.network.active = null;
      }
    }

    target: root.session && root.session.vpn ? root.session.vpn : null
    enabled: target !== null
  }

  Connections {
    function onActiveChanged(): void {
      if (root.session.ethernet && root.session.ethernet.active) {
        if (root.session.vpn)
          root.session.vpn.active = null;
        if (root.session.network)
          root.session.network.active = null;
      }
    }

    target: root.session && root.session.ethernet ? root.session.ethernet : null
    enabled: target !== null
  }

  Connections {
    function onActiveChanged(): void {
      if (root.session.network && root.session.network.active) {
        if (root.session.vpn)
          root.session.vpn.active = null;
        if (root.session.ethernet)
          root.session.ethernet.active = null;
      }
    }

    target: root.session && root.session.network ? root.session.network : null
    enabled: target !== null
  }

  StyledFlickable {
    id: page

    anchors.fill: parent
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    contentHeight: contentGrid.implicitHeight + Tokens.padding.normal * 2

    StyledScrollBar.vertical: StyledScrollBar {
      flickable: page
    }

    GridLayout {
      id: contentGrid

      x: Tokens.padding.normal
      y: Tokens.padding.normal
      width: page.width - Tokens.padding.normal * 2
      columns: 12
      rowSpacing: Tokens.spacing.small
      columnSpacing: Tokens.spacing.small

      NetworkCard {
        Layout.fillWidth: true
        Layout.columnSpan: root.compact ? 12 : 6
        icon: "router"
        title: qsTr("Network")
        subtitle: Nmcli.active ? qsTr("%1 connected").arg(Nmcli.active.ssid || qsTr("WiFi")) : (Nmcli.activeEthernet ? qsTr("%1 connected").arg(Nmcli.activeEthernet.interface || qsTr("Ethernet")) : qsTr("No active connection"))

        GridLayout {
          Layout.fillWidth: true
          columns: width > 360 ? 2 : 1
          rowSpacing: Tokens.spacing.small
          columnSpacing: Tokens.spacing.small

          MetricTile {
            Layout.fillWidth: true
            label: qsTr("WiFi")
            value: Nmcli.wifiEnabled ? qsTr("On") : qsTr("Off")
            icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
            active: Nmcli.wifiEnabled
          }

          MetricTile {
            Layout.fillWidth: true
            label: qsTr("Networks")
            value: qsTr("%1").arg(Nmcli.networks.length)
            icon: "signal_wifi_4_bar"
          }

          MetricTile {
            Layout.fillWidth: true
            label: qsTr("Ethernet")
            value: qsTr("%1").arg(Nmcli.ethernetDevices.length)
            icon: "cable"
            active: Nmcli.activeEthernet !== null
          }

          MetricTile {
            Layout.fillWidth: true
            label: qsTr("VPN")
            value: VPN.connected ? qsTr("On") : qsTr("%1").arg(GlobalConfig.utilities.vpn.provider.length)
            icon: VPN.connected ? "vpn_key" : "vpn_key_off"
            active: VPN.connected
          }
        }
      }

      NetworkCard {
        Layout.fillWidth: true
        Layout.columnSpan: root.compact ? 12 : 6
        icon: "tune"
        title: qsTr("Controls")
        subtitle: qsTr("Fast network actions")

        GridLayout {
          Layout.fillWidth: true
          columns: width > 360 ? 2 : 1
          rowSpacing: Tokens.spacing.small
          columnSpacing: Tokens.spacing.small

          QuickAction {
            Layout.fillWidth: true
            icon: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
            title: qsTr("WiFi")
            value: Nmcli.wifiEnabled ? qsTr("Enabled") : qsTr("Disabled")
            active: Nmcli.wifiEnabled
            onClicked: Nmcli.toggleWifi(null)
          }

          QuickAction {
            Layout.fillWidth: true
            icon: "wifi_find"
            title: qsTr("Scan")
            value: Nmcli.scanning ? qsTr("Scanning") : qsTr("Refresh nearby networks")
            active: Nmcli.scanning
            onClicked: Nmcli.rescanWifi()
          }

          QuickToggleRow {
            Layout.fillWidth: true
            icon: "wifi"
            title: qsTr("Wireless radio")
            checked: Nmcli.wifiEnabled
            onToggled: function (checked) {
              Nmcli.enableWifi(checked);
            }
          }

          QuickToggleRow {
            Layout.fillWidth: true
            icon: "vpn_key"
            title: qsTr("VPN service")
            checked: GlobalConfig.utilities.vpn.enabled
            onToggled: function (checked) {
              GlobalConfig.utilities.vpn.enabled = checked;
            }
          }
        }
      }

      NetworkCard {
        Layout.fillWidth: true
        Layout.columnSpan: root.compact ? 12 : 6
        icon: "wifi"
        title: qsTr("Wireless")
        subtitle: qsTr("%1 networks").arg(Nmcli.networks.length)

        WirelessList {
          Layout.fillWidth: true
          session: root.session
          showHeader: false
        }
      }

      NetworkCard {
        Layout.fillWidth: true
        Layout.columnSpan: root.compact ? 12 : 3
        icon: "vpn_key"
        title: qsTr("VPN")
        subtitle: GlobalConfig.utilities.vpn.enabled ? qsTr("Allowed") : qsTr("Disabled")

        VpnList {
          Layout.fillWidth: true
          session: root.session
          showHeader: false
        }
      }

      NetworkCard {
        Layout.fillWidth: true
        Layout.columnSpan: root.compact ? 12 : 3
        icon: "cable"
        title: qsTr("Ethernet")
        subtitle: qsTr("%1 devices").arg(Nmcli.ethernetDevices.length)

        EthernetList {
          Layout.fillWidth: true
          session: root.session
          showHeader: false
        }
      }

      NetworkCard {
        id: detailsHost

        property Component targetComponent: root.detailsComponent()
        property Component nextComponent: root.detailsComponent()

        Layout.fillWidth: true
        Layout.columnSpan: 12
        icon: root.selectedIcon()
        title: root.selectedTitle()
        subtitle: qsTr("Details and current settings")

        Loader {
          id: detailsLoader

          Layout.fillWidth: true
          asynchronous: true
          opacity: 1
          scale: 1
          transformOrigin: Item.Center
          sourceComponent: detailsHost.targetComponent
        }

      }
    }
  }

  Component {
    id: overviewDetailsComponent

    GridLayout {
      columns: root.compact ? 2 : 4
      rowSpacing: Tokens.spacing.small
      columnSpacing: Tokens.spacing.small

      MetricTile {
        Layout.fillWidth: true
        label: qsTr("Network")
        value: Nmcli.active ? (Nmcli.active.ssid || qsTr("WiFi")) : (Nmcli.activeEthernet ? (Nmcli.activeEthernet.interface || qsTr("Ethernet")) : qsTr("Disconnected"))
        icon: Nmcli.active ? "wifi" : (Nmcli.activeEthernet ? "cable" : "link_off")
        active: Nmcli.active !== null || Nmcli.activeEthernet !== null
      }

      MetricTile {
        Layout.fillWidth: true
        label: qsTr("Signal")
        value: Nmcli.active ? qsTr("%1%").arg(Nmcli.active.strength) : qsTr("N/A")
        icon: "network_check"
        active: Nmcli.active !== null
      }

      MetricTile {
        Layout.fillWidth: true
        label: qsTr("Security")
        value: Nmcli.active ? (Nmcli.active.isSecure ? qsTr("Secured") : qsTr("Open")) : qsTr("N/A")
        icon: Nmcli.active && Nmcli.active.isSecure ? "lock" : "lock_open"
        active: Nmcli.active !== null && Nmcli.active.isSecure
      }

      MetricTile {
        Layout.fillWidth: true
        label: qsTr("Frequency")
        value: Nmcli.active ? qsTr("%1 MHz").arg(Nmcli.active.frequency) : qsTr("N/A")
        icon: "settings_input_antenna"
        active: Nmcli.active !== null
      }
    }
  }

  Component {
    id: ethernetDetailsComponent

    EthernetDetails {
      Layout.fillWidth: true
      session: root.session
    }
  }

  Component {
    id: wirelessDetailsComponent

    WirelessDetails {
      Layout.fillWidth: true
      session: root.session
    }
  }

  Component {
    id: vpnDetailsComponent

    VpnDetails {
      Layout.fillWidth: true
      session: root.session
    }
  }

  WirelessPasswordDialog {
    anchors.fill: parent
    session: root.session
    z: 1000
  }

  component NetworkCard: StyledRect {
    id: card

    required property string icon
    required property string title
    property string subtitle: ""
    default property alias content: body.data

    Layout.fillWidth: true
    implicitHeight: cardLayout.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainerHigh
    clip: true

    ColumnLayout {
      id: cardLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        StyledRect {
          Layout.alignment: Qt.AlignVCenter
          implicitWidth: 30
          implicitHeight: 30
          radius: Tokens.rounding.small
          color: Colours.palette.m3surfaceContainerHighest

          MaterialIcon {
            anchors.centerIn: parent
            text: card.icon
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.normal
            fill: 1
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: card.title
            font.pointSize: Tokens.font.size.normal
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            visible: card.subtitle !== ""
            text: card.subtitle
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      ColumnLayout {
        id: body

        Layout.fillWidth: true
        spacing: Tokens.spacing.small
      }
    }
  }

  component MetricTile: StyledRect {
    id: metric

    required property string label
    required property string value
    property string icon: "monitoring"
    property bool active: false

    implicitHeight: 44
    radius: Tokens.rounding.small
    color: metric.active ? Colours.palette.m3secondaryContainer : Colours.palette.m3surfaceContainer

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.smaller
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: metric.icon
        color: metric.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: metric.active ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: metric.value
          color: metric.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
          font.weight: 700
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: metric.label
          color: metric.active ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }
    }
  }

  component QuickAction: StyledRect {
    id: action

    required property string icon
    required property string title
    required property string value
    property bool active: false

    signal clicked

    implicitHeight: 40
    radius: Tokens.rounding.small
    color: action.active ? Colours.palette.m3primaryContainer : Colours.palette.m3surfaceContainer

    StateLayer {
      onClicked: action.clicked()
      color: action.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
      radius: parent.radius
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.smaller
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: action.icon
        color: action.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
        fill: action.active ? 1 : 0
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        spacing: 0

        StyledText {
          Layout.fillWidth: true
          text: action.title
          color: action.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurface
          font.weight: 650
          elide: Text.ElideRight
        }

        StyledText {
          Layout.fillWidth: true
          text: action.value
          color: action.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
          font.pointSize: Tokens.font.size.small
          elide: Text.ElideRight
        }
      }
    }
  }

  component QuickToggleRow: StyledRect {
    id: toggleRow

    required property string icon
    required property string title
    property bool checked: false

    signal toggled(bool checked)

    implicitHeight: 40
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer

    RowLayout {
      anchors.fill: parent
      anchors.margins: Tokens.padding.smaller
      spacing: Tokens.spacing.small

      MaterialIcon {
        Layout.alignment: Qt.AlignVCenter
        text: toggleRow.icon
        color: Colours.palette.m3onSurfaceVariant
        font.pointSize: Tokens.font.size.small
      }

      StyledText {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: toggleRow.title
        font.weight: 650
        elide: Text.ElideRight
      }

      StyledSwitch {
        Layout.alignment: Qt.AlignVCenter
        checked: toggleRow.checked
        onToggled: toggleRow.toggled(checked)
      }
    }
  }
}
