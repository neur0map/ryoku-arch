import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.System
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: NotificationService.doNotDisturb ? "bell-off" : "bell"
  hot: NotificationService.doNotDisturb
  tooltipText: I18n.tr("common.notifications")
  onClicked: PanelService.getPanel("notificationHistoryPanel", screen)?.toggle(this)
  onRightClicked: NotificationService.doNotDisturb = !NotificationService.doNotDisturb
}
