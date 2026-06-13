import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NText {
    text: qsTr("Widget settings")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NCollapsible {
    label: qsTr("Workspaces")
    Layout.fillWidth: true

    NSpinBox {
      Layout.fillWidth: true
      label: qsTr("Workspaces shown")
      from: 1
      to: 10
      stepSize: 1
      value: GlobalConfig.bar.workspaces.shown
      onValueChanged: {
        if (GlobalConfig.bar.workspaces.shown !== value) {
          GlobalConfig.bar.workspaces.shown = value;
          GlobalConfig.save();
        }
      }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Active indicator")
      checked: GlobalConfig.bar.workspaces.activeIndicator
      onToggled: checked => {
                   GlobalConfig.bar.workspaces.activeIndicator = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Occupied background")
      checked: GlobalConfig.bar.workspaces.occupiedBg
      onToggled: checked => {
                   GlobalConfig.bar.workspaces.occupiedBg = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Show window icons")
      checked: GlobalConfig.bar.workspaces.showWindows
      onToggled: checked => {
                   GlobalConfig.bar.workspaces.showWindows = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Show windows on special workspaces")
      checked: GlobalConfig.bar.workspaces.showWindowsOnSpecialWorkspaces
      onToggled: checked => {
                   GlobalConfig.bar.workspaces.showWindowsOnSpecialWorkspaces = checked;
                   GlobalConfig.save();
                 }
    }
    NSpinBox {
      Layout.fillWidth: true
      label: qsTr("Max window icons")
      from: 1
      to: 15
      stepSize: 1
      value: GlobalConfig.bar.workspaces.maxWindowIcons
      onValueChanged: {
        if (GlobalConfig.bar.workspaces.maxWindowIcons !== value) {
          GlobalConfig.bar.workspaces.maxWindowIcons = value;
          GlobalConfig.save();
        }
      }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Active trail")
      checked: GlobalConfig.bar.workspaces.activeTrail
      onToggled: checked => {
                   GlobalConfig.bar.workspaces.activeTrail = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Per-monitor workspaces")
      checked: GlobalConfig.bar.workspaces.perMonitorWorkspaces
      onToggled: checked => {
                   GlobalConfig.bar.workspaces.perMonitorWorkspaces = checked;
                   GlobalConfig.save();
                 }
    }
    NComboBox {
      Layout.fillWidth: true
      label: qsTr("Label capitalisation")
      model: [
        {
          "key": "preserve",
          "name": qsTr("Preserve")
        },
        {
          "key": "upper",
          "name": qsTr("UPPERCASE")
        },
        {
          "key": "lower",
          "name": qsTr("lowercase")
        }
      ]
      currentKey: GlobalConfig.bar.workspaces.capitalisation
      onSelected: key => {
                    GlobalConfig.bar.workspaces.capitalisation = key;
                    GlobalConfig.save();
                  }
    }
  }

  NCollapsible {
    label: qsTr("Active window")
    Layout.fillWidth: true

    NToggle {
      Layout.fillWidth: true
      label: qsTr("Compact")
      checked: GlobalConfig.bar.activeWindow.compact
      onToggled: checked => {
                   GlobalConfig.bar.activeWindow.compact = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Inverted")
      checked: GlobalConfig.bar.activeWindow.inverted
      onToggled: checked => {
                   GlobalConfig.bar.activeWindow.inverted = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Show on hover")
      checked: GlobalConfig.bar.activeWindow.showOnHover
      onToggled: checked => {
                   GlobalConfig.bar.activeWindow.showOnHover = checked;
                   GlobalConfig.save();
                 }
    }
  }

  NCollapsible {
    label: qsTr("System tray")
    Layout.fillWidth: true

    NToggle {
      Layout.fillWidth: true
      label: qsTr("Background")
      checked: GlobalConfig.bar.tray.background
      onToggled: checked => {
                   GlobalConfig.bar.tray.background = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Recolour icons")
      checked: GlobalConfig.bar.tray.recolour
      onToggled: checked => {
                   GlobalConfig.bar.tray.recolour = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Compact")
      checked: GlobalConfig.bar.tray.compact
      onToggled: checked => {
                   GlobalConfig.bar.tray.compact = checked;
                   GlobalConfig.save();
                 }
    }
  }

  NCollapsible {
    label: qsTr("Clock")
    Layout.fillWidth: true

    NToggle {
      Layout.fillWidth: true
      label: qsTr("Background")
      checked: GlobalConfig.bar.clock.background
      onToggled: checked => {
                   GlobalConfig.bar.clock.background = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Show date")
      checked: GlobalConfig.bar.clock.showDate
      onToggled: checked => {
                   GlobalConfig.bar.clock.showDate = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Show icon")
      checked: GlobalConfig.bar.clock.showIcon
      onToggled: checked => {
                   GlobalConfig.bar.clock.showIcon = checked;
                   GlobalConfig.save();
                 }
    }
  }

  NCollapsible {
    label: qsTr("Status icons")
    Layout.fillWidth: true

    NToggle {
      Layout.fillWidth: true
      label: qsTr("Audio")
      checked: GlobalConfig.bar.status.showAudio
      onToggled: checked => {
                   GlobalConfig.bar.status.showAudio = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Microphone")
      checked: GlobalConfig.bar.status.showMicrophone
      onToggled: checked => {
                   GlobalConfig.bar.status.showMicrophone = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Keyboard layout")
      checked: GlobalConfig.bar.status.showKbLayout
      onToggled: checked => {
                   GlobalConfig.bar.status.showKbLayout = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Network")
      checked: GlobalConfig.bar.status.showNetwork
      onToggled: checked => {
                   GlobalConfig.bar.status.showNetwork = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Wi-Fi")
      checked: GlobalConfig.bar.status.showWifi
      onToggled: checked => {
                   GlobalConfig.bar.status.showWifi = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Bluetooth")
      checked: GlobalConfig.bar.status.showBluetooth
      onToggled: checked => {
                   GlobalConfig.bar.status.showBluetooth = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Battery")
      checked: GlobalConfig.bar.status.showBattery
      onToggled: checked => {
                   GlobalConfig.bar.status.showBattery = checked;
                   GlobalConfig.save();
                 }
    }
    NToggle {
      Layout.fillWidth: true
      label: qsTr("Lock status")
      checked: GlobalConfig.bar.status.showLockStatus
      onToggled: checked => {
                   GlobalConfig.bar.status.showLockStatus = checked;
                   GlobalConfig.save();
                 }
    }
  }
}
