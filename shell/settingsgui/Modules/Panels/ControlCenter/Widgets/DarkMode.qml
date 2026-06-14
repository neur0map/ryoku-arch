import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: "dark-mode"
  tooltipText: GlobalConfig.colorSchemes.darkMode ? I18n.tr("tooltips.switch-to-light-mode") : I18n.tr("tooltips.switch-to-dark-mode")
  onClicked: {
    GlobalConfig.colorSchemes.darkMode = !GlobalConfig.colorSchemes.darkMode;
    GlobalConfig.save();
  }
}
