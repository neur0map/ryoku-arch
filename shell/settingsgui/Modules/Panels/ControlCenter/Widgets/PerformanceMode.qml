import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: PowerProfileService.performanceMode ? "rocket" : "rocket-off"
  tooltipText: I18n.tr("tooltips.performance-mode-enabled")
  hot: PowerProfileService.performanceMode
  onClicked: PowerProfileService.togglePerformanceMode()
}
