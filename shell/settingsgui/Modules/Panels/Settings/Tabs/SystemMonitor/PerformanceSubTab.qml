import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.performance-mode-disable-wallpaper-label")
    description: I18n.tr("panels.system.performance-mode-disable-wallpaper-description")
    checked: !Settings.data.performanceMode.disableWallpaper
    defaultValue: !Settings.getDefaultValue("performanceMode.disableWallpaper")
    onToggled: checked => Settings.data.performanceMode.disableWallpaper = !checked
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.system.performance-mode-disable-desktop-widgets-label")
    description: I18n.tr("panels.system.performance-mode-disable-desktop-widgets-description")
    checked: !Settings.data.performanceMode.disableDesktopWidgets
    defaultValue: !Settings.getDefaultValue("performanceMode.disableDesktopWidgets")
    onToggled: checked => Settings.data.performanceMode.disableDesktopWidgets = !checked
  }
}
