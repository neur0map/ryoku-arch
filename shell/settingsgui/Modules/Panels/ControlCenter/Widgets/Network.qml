import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Networking
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen
  icon: NetworkService.getIcon()
  tooltipText: NetworkService.getStatusText(true)
  onClicked: {
    var panel = PanelService.getPanel("networkPanel", screen);
    panel?.toggle(this);
  }
  onRightClicked: {
    if (!NetworkService.airplaneModeEnabled) {
      NetworkService.setWifiEnabled(!NetworkService.wifiEnabled);
    }
  }
}
