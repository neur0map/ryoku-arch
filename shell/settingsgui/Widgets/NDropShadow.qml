import QtQuick
import QtQuick.Effects
import qs.settingsgui.Commons
import qs.settingsgui.Services.Power

Item {
  id: root

  required property var source

  property bool autoPaddingEnabled: false
  property real shadowHorizontalOffset: Settings.data.general.shadowOffsetX
  property real shadowVerticalOffset: Settings.data.general.shadowOffsetY
  property real shadowOpacity: Style.shadowOpacity
  property color shadowColor: "black"
  property real shadowBlur: Style.shadowBlur

  layer.enabled: Settings.data.general.enableShadows && !PowerProfileService.performanceMode
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
