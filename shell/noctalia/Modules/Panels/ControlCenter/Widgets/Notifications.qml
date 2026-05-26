import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.System
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
  hot: NotificationService.doNotDisturb
  tooltipText: I18n.tr("common.notifications")
  onClicked: PanelService.getPanel("notificationHistoryPanel", screen)?.toggle(this)
  onRightClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
}
