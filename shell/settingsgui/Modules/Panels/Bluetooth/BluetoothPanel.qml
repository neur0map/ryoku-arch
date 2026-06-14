import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Ryoku.Config
import "../Settings/Tabs/Connections" as BluetoothPrefs
import qs.settingsgui.Commons
import qs.settingsgui.Modules.MainScreen
import qs.settingsgui.Modules.Panels.Settings
import qs.settingsgui.Services.Hardware
import qs.settingsgui.Services.Networking
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

SmartPanel {
  id: root

  preferredWidth: Math.round(440 * Style.uiScaleRatio)
  preferredHeight: Math.round(500 * Style.uiScaleRatio)

  panelContent: Rectangle {
    id: panelContent
    color: "transparent"

    property real contentPreferredHeight: Math.min(root.preferredHeight, mainColumn.implicitHeight + Style.margin2L)

    ColumnLayout {
      id: mainColumn
      anchors.fill: parent
      anchors.margins: Style.marginL
      spacing: Style.marginM

      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerRow.implicitHeight + Style.margin2M

        RowLayout {
          id: headerRow
          anchors.fill: parent
          anchors.margins: Style.marginM

          NIcon {
            icon: BluetoothService.enabled ? "bluetooth" : "bluetooth-off"
            pointSize: Style.fontSizeXXL
            color: BluetoothService.enabled ? Color.mPrimary : Color.mOnSurfaceVariant
          }

          NLabel {
            label: I18n.tr("common.bluetooth")
            Layout.fillWidth: true
          }

          NToggle {
            id: bluetoothSwitch
            checked: BluetoothService.enabled
            enabled: !NetworkService.airplaneModeEnabled && BluetoothService.bluetoothAvailable
            onToggled: checked => BluetoothService.setBluetoothEnabled(checked)
            baseSize: Style.baseWidgetSize * 0.65
          }

          NIconButton {
            icon: GlobalConfig.network.bluetoothAutoConnect ? "bluetooth-connected" : "bluetooth"
            tooltipText: GlobalConfig.network.bluetoothAutoConnect ? I18n.tr("tooltips.bluetooth-auto-connect-on") : I18n.tr("tooltips.bluetooth-auto-connect-off")
            colorFg: GlobalConfig.network.bluetoothAutoConnect ? Color.mPrimary : Color.mOnSurfaceVariant
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              GlobalConfig.network.bluetoothAutoConnect = !GlobalConfig.network.bluetoothAutoConnect;
              GlobalConfig.save();
            }
          }

          NIconButton {
            icon: "settings"
            tooltipText: I18n.tr("tooltips.open-settings")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 1, screen)
          }

          NIconButton {
            icon: "close"
            tooltipText: I18n.tr("common.close")
            baseSize: Style.baseWidgetSize * 0.8
            onClicked: {
              root.close();
            }
          }
        }
      }

      NScrollView {
        id: bluetoothScrollView
        Layout.fillWidth: true
        Layout.fillHeight: true
        horizontalPolicy: ScrollBar.AlwaysOff
        verticalPolicy: ScrollBar.AsNeeded
        reserveScrollbarSpace: false
        gradientColor: Color.mSurface

        ColumnLayout {
          id: devicesList
          width: bluetoothScrollView.availableWidth
          spacing: Style.marginM

          NBox {
            id: disabledBox
            visible: !BluetoothService.enabled
            Layout.fillWidth: true
            Layout.preferredHeight: disabledColumn.implicitHeight + Style.margin2M

            ColumnLayout {
              id: disabledColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginL

              Item {
                Layout.fillHeight: true
              }

              NIcon {
                icon: "bluetooth-off"
                pointSize: 48
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: I18n.tr("bluetooth.panel.disabled")
                pointSize: Style.fontSizeL
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: I18n.tr("bluetooth.panel.enable-message")
                pointSize: Style.fontSizeS
                color: Color.mOnSurfaceVariant
                horizontalAlignment: Text.AlignHCenter
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
              }

              Item {
                Layout.fillHeight: true
              }
            }
          }

          // Empty state when no paired devices
          NBox {
            id: emptyBox
            visible: {
              if (!BluetoothService.enabled || !BluetoothService.devices)
                return false;
              // Pulling pairedDevices count from the source component
              return (btSource.pairedDevices.length === 0 && btSource.connectedDevices.length === 0);
            }
            Layout.fillWidth: true
            Layout.preferredHeight: emptyColumn.implicitHeight + Style.margin2M

            ColumnLayout {
              id: emptyColumn
              anchors.fill: parent
              anchors.margins: Style.marginM
              spacing: Style.marginL

              Item {
                Layout.fillHeight: true
              }

              NIcon {
                icon: "bluetooth"
                pointSize: 48
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }

              NText {
                text: I18n.tr("bluetooth.panel.no-devices")
                pointSize: Style.fontSizeL
                color: Color.mOnSurfaceVariant
                Layout.alignment: Qt.AlignHCenter
              }

              NButton {
                text: I18n.tr("common.settings")
                icon: "settings"
                Layout.alignment: Qt.AlignHCenter
                onClicked: SettingsPanelService.openToTab(SettingsPanel.Tab.Connections, 1, screen)
              }

              Item {
                Layout.fillHeight: true
              }
            }
          }

          // Pull connected/paired lists from BluetoothSubTab
          BluetoothPrefs.BluetoothSubTab {
            id: btSource
            Layout.fillWidth: true
            showOnlyLists: true
            visible: !disabledBox.visible && !emptyBox.visible
          }
        }
      }
    }
  }
}
