import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: "dark-mode"
  tooltipText: Settings.data.colorSchemes.darkMode ? I18n.tr("tooltips.switch-to-light-mode") : I18n.tr("tooltips.switch-to-dark-mode")
  onClicked: Settings.data.colorSchemes.darkMode = !Settings.data.colorSchemes.darkMode
}
