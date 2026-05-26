import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.Power
import qs.noctalia.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: IdleInhibitorService.isInhibited ? "keep-awake-on" : "keep-awake-off"
  hot: IdleInhibitorService.isInhibited
  tooltipText: I18n.tr("tooltips.keep-awake")
  onClicked: IdleInhibitorService.manualToggle()
}
