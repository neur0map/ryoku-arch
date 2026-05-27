pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth
import Ryoku.Config
import qs.components
import qs.services

// Adapted from Ambxst modules/widgets/dashboard/widgets/QuickControls.qml.
StyledRect {
  id: root

  signal requestLens
  signal requestColorPicker
  signal requestRecord

  Layout.alignment: Qt.AlignHCenter
  implicitWidth: internalBgRect.implicitWidth + 8
  implicitHeight: columnLayout.implicitHeight + 8
  radius: 18
  color: Colours.palette.m3surfaceContainerLow

  ColumnLayout {
    id: columnLayout

    anchors.fill: parent
    anchors.margins: 4
    spacing: 0

    StyledRect {
      id: internalBgRect

      Layout.alignment: Qt.AlignHCenter
      implicitWidth: buttonRow.implicitWidth + 8
      implicitHeight: buttonRow.implicitHeight + 8
      radius: 14
      color: Colours.layer(Colours.palette.m3surfaceContainer, 2)

      GridLayout {
        id: buttonRow

        anchors.centerIn: parent
        columns: 5
        columnSpacing: 4
        rowSpacing: 4

        ControlButton {
          iconName: Nmcli.wifiEnabled ? "wifi" : "wifi_off"
          isActive: Nmcli.wifiEnabled
          tooltipText: Nmcli.wifiEnabled ? qsTr("Wi-Fi: On") : qsTr("Wi-Fi: Off")
          onClicked: Nmcli.toggleWifi()
        }

        ControlButton {
          readonly property var adapter: Bluetooth.defaultAdapter

          iconName: !adapter?.enabled ? "bluetooth_disabled"
            : Bluetooth.devices.values.some(d => d.connected) ? "bluetooth_connected"
            : "bluetooth"
          isActive: adapter?.enabled ?? false
          disabled: !adapter
          tooltipText: isActive ? qsTr("Bluetooth: On") : qsTr("Bluetooth: Off")
          onClicked: {
            if (adapter)
              adapter.enabled = !adapter.enabled;
          }
        }

        ControlButton {
          iconName: Notifs.dnd ? "notifications_off" : "notifications"
          isActive: Notifs.dnd
          tooltipText: Notifs.dnd ? qsTr("Notifications: Silent") : qsTr("Notifications: On")
          onClicked: Notifs.dnd = !Notifs.dnd
        }

        ControlButton {
          iconName: "coffee"
          isActive: IdleInhibitor.enabled
          tooltipText: IdleInhibitor.enabled ? qsTr("Keep Awake: On") : qsTr("Keep Awake: Off")
          onClicked: IdleInhibitor.enabled = !IdleInhibitor.enabled
        }

        ControlButton {
          iconName: "sports_esports"
          isActive: GameMode.enabled
          tooltipText: GameMode.enabled ? qsTr("Game Mode: On") : qsTr("Game Mode: Off")
          onClicked: GameMode.enabled = !GameMode.enabled
        }

        ControlButton {
          iconName: "image_search"
          tooltipText: qsTr("Google Lens")
          onClicked: root.requestLens()
        }

        ControlButton {
          iconName: "colorize"
          tooltipText: qsTr("Color picker")
          onClicked: root.requestColorPicker()
        }

        ControlButton {
          iconName: "screen_record"
          isActive: Recorder.running
          tooltipText: Recorder.running ? qsTr("Recording running") : qsTr("Screen recorder")
          onClicked: root.requestRecord()
        }
      }
    }
  }
}
