import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.Networking
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

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
