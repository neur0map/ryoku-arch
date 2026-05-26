import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.Power
import qs.noctalia.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: PowerProfileService.noctaliaPerformanceMode ? "rocket" : "rocket-off"
  tooltipText: I18n.tr("tooltips.noctalia-performance-enabled")
  hot: PowerProfileService.noctaliaPerformanceMode
  onClicked: PowerProfileService.toggleNoctaliaPerformance()
}
