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

  // The top-notch layout is fixed; these toggle what each notch shows.
  // Defaults match the notch's built-in look, so nothing changes until edited.

  NText {
    text: qsTr("Status icons")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Audio")
    checked: GlobalConfig.bar.topNotch.status.audio
    onToggled: checked => { GlobalConfig.bar.topNotch.status.audio = checked; GlobalConfig.save(); }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Network")
    checked: GlobalConfig.bar.topNotch.status.network
    onToggled: checked => { GlobalConfig.bar.topNotch.status.network = checked; GlobalConfig.save(); }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Battery")
    checked: GlobalConfig.bar.topNotch.status.battery
    onToggled: checked => { GlobalConfig.bar.topNotch.status.battery = checked; GlobalConfig.save(); }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Bluetooth")
    checked: GlobalConfig.bar.topNotch.status.bluetooth
    onToggled: checked => { GlobalConfig.bar.topNotch.status.bluetooth = checked; GlobalConfig.save(); }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Microphone")
    checked: GlobalConfig.bar.topNotch.status.microphone
    onToggled: checked => { GlobalConfig.bar.topNotch.status.microphone = checked; GlobalConfig.save(); }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Keyboard layout")
    checked: GlobalConfig.bar.topNotch.status.keyboard
    onToggled: checked => { GlobalConfig.bar.topNotch.status.keyboard = checked; GlobalConfig.save(); }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Lock keys")
    checked: GlobalConfig.bar.topNotch.status.lockStatus
    onToggled: checked => { GlobalConfig.bar.topNotch.status.lockStatus = checked; GlobalConfig.save(); }
  }

  NDivider { Layout.fillWidth: true }

  NText {
    text: qsTr("Clock")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: qsTr("Show date")
    checked: GlobalConfig.bar.topNotch.clock.showDate
    onToggled: checked => { GlobalConfig.bar.topNotch.clock.showDate = checked; GlobalConfig.save(); }
  }
  NToggle {
    Layout.fillWidth: true
    label: qsTr("Show seconds")
    checked: GlobalConfig.bar.topNotch.clock.showSeconds
    onToggled: checked => { GlobalConfig.bar.topNotch.clock.showSeconds = checked; GlobalConfig.save(); }
  }

  NDivider { Layout.fillWidth: true }

  NText {
    text: qsTr("Workspaces")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

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
}
