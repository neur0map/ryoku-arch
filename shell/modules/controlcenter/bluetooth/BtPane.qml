pragma ComponentBehavior: Bound

import ".."
import "../components"
import "."
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Ryoku.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services

Item {
  id: root

  required property Session session

  anchors.fill: parent

  StyledFlickable {
    id: page

    anchors.fill: parent
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    flickableDirection: Flickable.VerticalFlick
    contentHeight: content.implicitHeight + Tokens.padding.normal * 2

    StyledScrollBar.vertical: StyledScrollBar {
      flickable: page
    }

    GridLayout {
      id: content

      x: Tokens.padding.normal
      y: Tokens.padding.normal
      width: page.width - Tokens.padding.normal * 2
      columns: page.width > 620 ? 5 : 1
      columnSpacing: Tokens.spacing.small
      rowSpacing: Tokens.spacing.small

      BluetoothDock {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        Layout.columnSpan: page.width > 620 ? 2 : 1
        icon: "devices"
        title: qsTr("Devices")
        detail: qsTr("%1 available").arg(Bluetooth.devices.values.length)

        DeviceList {
          Layout.fillWidth: true
          Layout.preferredHeight: implicitHeight
          session: root.session
          showHeader: false
        }
      }

      BluetoothDock {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        Layout.columnSpan: page.width > 620 ? 3 : 1
        icon: root.session.bt.active ? "bluetooth_connected" : "settings_bluetooth"
        title: root.session.bt.active ? (root.session.bt.active.name ?? qsTr("Device")) : qsTr("Adapter")
        detail: root.session.bt.active ? qsTr("Device controls") : (Bluetooth.defaultAdapter?.name ?? qsTr("No adapter"))

        Settings {
          Layout.fillWidth: true
          Layout.preferredHeight: 420
          visible: !root.session.bt.active
          session: root.session
        }

        Loader {
          id: paneLoader

          Layout.fillWidth: true
          Layout.preferredHeight: item ? Math.max(item.implicitHeight, item.childrenRect.height) : 0
          active: root.session.bt.active
          asynchronous: true
          sourceComponent: detailsComponent

          Binding {
            target: paneLoader.item
            property: "width"
            value: paneLoader.width
            when: paneLoader.item !== null
          }
        }
      }
    }
  }

  Component {
    id: detailsComponent

    Details {
      session: root.session
    }
  }

  component BluetoothDock: StyledRect {
    id: dock

    required property string icon
    required property string title
    property string detail: ""
    default property alias content: dockBody.data

    implicitHeight: dockLayout.implicitHeight + Tokens.padding.small * 2
    radius: Tokens.rounding.small
    color: Colours.palette.m3surfaceContainer
    clip: true

    ColumnLayout {
      id: dockLayout

      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Tokens.padding.small
      spacing: Tokens.spacing.small

      RowLayout {
        Layout.fillWidth: true
        spacing: Tokens.spacing.small

        MaterialIcon {
          Layout.alignment: Qt.AlignVCenter
          text: dock.icon
          color: Colours.palette.m3primary
          fill: 1
        }

        ColumnLayout {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          spacing: 0

          StyledText {
            Layout.fillWidth: true
            text: dock.title
            font.weight: 700
            elide: Text.ElideRight
          }

          StyledText {
            Layout.fillWidth: true
            visible: dock.detail !== ""
            text: dock.detail
            color: Colours.palette.m3onSurfaceVariant
            font.pointSize: Tokens.font.size.small
            elide: Text.ElideRight
          }
        }
      }

      ColumnLayout {
        id: dockBody

        Layout.fillWidth: true
        spacing: Tokens.spacing.small
      }
    }
  }
}
