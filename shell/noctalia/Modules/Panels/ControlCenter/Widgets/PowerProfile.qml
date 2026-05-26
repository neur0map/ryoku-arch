import QtQuick.Layouts
import Quickshell
import Quickshell.Services.UPower
import qs.noctalia.Commons
import qs.noctalia.Services.Power
import qs.noctalia.Widgets

// Performance
NIconButtonHot {
  property ShellScreen screen

  readonly property bool hasPP: PowerProfileService.available

  enabled: hasPP
  icon: PowerProfileService.getIcon()
  hot: !PowerProfileService.isDefault()
  tooltipText: I18n.tr("control-center.power-profile.tooltip-action")
  onClicked: PowerProfileService.cycleProfile()
}
