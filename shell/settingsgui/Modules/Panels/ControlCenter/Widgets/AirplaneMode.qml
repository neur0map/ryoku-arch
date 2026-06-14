import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.Networking
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

NIconButtonHot {
  property ShellScreen screen

  icon: !NetworkService.airplaneModeEnabled ? "plane-off" : "plane"
  hot: NetworkService.airplaneModeEnabled
  tooltipText: I18n.tr("toast.airplane-mode.title")
  onClicked: {
    NetworkService.setAirplaneMode(!NetworkService.airplaneModeEnabled);
  }
  enabled: NetworkService.wifiAvailable && BluetoothService.bluetoothAvailable
}
