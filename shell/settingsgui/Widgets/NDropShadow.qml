import QtQuick
import Ryoku.Config
import QtQuick.Effects
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power

Item {
  id: root

  required property var source

  property bool autoPaddingEnabled: false
  property real shadowHorizontalOffset: GlobalConfig.general.shadowOffsetX
  property real shadowVerticalOffset: GlobalConfig.general.shadowOffsetY
  property real shadowOpacity: Style.shadowOpacity
  property color shadowColor: "black"
  property real shadowBlur: Style.shadowBlur

  layer.enabled: GlobalConfig.general.enableShadows && !PowerProfileService.performanceMode
  layer.effect: MultiEffect {
    source: root.source
    shadowEnabled: true
    blurMax: Style.shadowBlurMax
    shadowBlur: root.shadowBlur
    shadowOpacity: root.shadowOpacity
    shadowColor: root.shadowColor
    shadowHorizontalOffset: root.shadowHorizontalOffset
    shadowVerticalOffset: root.shadowVerticalOffset
    autoPaddingEnabled: root.autoPaddingEnabled
  }
}
