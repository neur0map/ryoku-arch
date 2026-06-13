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

  // Scroll actions and hover popouts.

  NText {
    text: qsTr("Scroll actions")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NToggle {
    label: qsTr("Scroll to switch workspace")
    description: qsTr("Scroll over the bar to move between workspaces.")
    checked: GlobalConfig.bar.scrollActions.workspaces
    onToggled: checked => {
                 GlobalConfig.bar.scrollActions.workspaces = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    label: qsTr("Scroll to change volume")
    description: qsTr("Scroll over the audio status icon to adjust volume.")
    checked: GlobalConfig.bar.scrollActions.volume
    onToggled: checked => {
                 GlobalConfig.bar.scrollActions.volume = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    label: qsTr("Scroll to change brightness")
    description: qsTr("Scroll over the brightness status icon to adjust screen brightness.")
    checked: GlobalConfig.bar.scrollActions.brightness
    onToggled: checked => {
                 GlobalConfig.bar.scrollActions.brightness = checked;
                 GlobalConfig.save();
               }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    text: qsTr("Hover popouts")
    pointSize: Style.fontSizeM
    font.weight: Style.fontWeightBold
    color: Color.mOnSurface
    Layout.fillWidth: true
  }

  NToggle {
    label: qsTr("Active window popout")
    description: qsTr("Show a popout with window details when hovering the active window widget.")
    checked: GlobalConfig.bar.popouts.activeWindow
    onToggled: checked => {
                 GlobalConfig.bar.popouts.activeWindow = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    label: qsTr("Tray popout")
    description: qsTr("Show a popout when hovering the system tray.")
    checked: GlobalConfig.bar.popouts.tray
    onToggled: checked => {
                 GlobalConfig.bar.popouts.tray = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    label: qsTr("Status icons popout")
    description: qsTr("Show a popout when hovering the status icons.")
    checked: GlobalConfig.bar.popouts.statusIcons
    onToggled: checked => {
                 GlobalConfig.bar.popouts.statusIcons = checked;
                 GlobalConfig.save();
               }
  }
}
