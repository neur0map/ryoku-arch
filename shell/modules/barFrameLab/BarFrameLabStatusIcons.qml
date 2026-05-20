pragma ComponentBehavior: Bound

import qs
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

ColumnLayout {
  id: root

  readonly property color textColor: Config.options?.barFrameLab?.textColor ?? Appearance.colors.colOnLayer0

  spacing: 10

  component StatusIcon: MaterialSymbol {
    iconSize: Appearance.font.pixelSize.larger
    color: root.textColor
  }

  StatusIcon {
    text: Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
  }

  StatusIcon {
    text: Network.materialSymbol
  }

  StatusIcon {
    visible: BluetoothStatus.available
    text: BluetoothStatus.activeIcon
  }

  StatusIcon {
    visible: Battery.available
    text: Battery.isCharging ? "battery_charging_full" : "battery_android_full"
    fill: Battery.percentage
  }
}
