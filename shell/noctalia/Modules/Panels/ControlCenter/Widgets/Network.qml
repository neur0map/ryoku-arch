import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.Networking
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

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
