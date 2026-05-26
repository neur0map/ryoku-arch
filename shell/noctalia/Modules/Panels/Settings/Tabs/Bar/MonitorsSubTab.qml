import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // Interface kept for BarTab.qml compatibility (greyed content doesn't use these).
  property var addMonitor: null
  property var removeMonitor: null

  // TODO: wire bar per-monitor enable/disable to ryoku (ryoku uses GlobalConfig.bar.excludedScreens QStringList,
  //   inverse of noctalia monitors include-list; per-screen position/density/displayMode overrides not in ryoku barconfig)

  NText {
    text: I18n.tr("panels.bar.monitors-desc-new")
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }

  Repeater {
    model: Quickshell.screens || []
    delegate: NBox {
      id: monitorCard
      Layout.fillWidth: true
      implicitHeight: cardContent.implicitHeight + Style.margin2L
      color: Color.mSurface
      enabled: false
      opacity: 0.45

      required property var modelData
      readonly property string screenName: modelData.name || "Unknown"
      readonly property real compositorScale: {
        const info = CompositorService.displayScales[screenName];
        return (info && info.scale) ? info.scale : 1.0;
      }

      ColumnLayout {
        id: cardContent
        anchors.fill: parent
        anchors.margins: Style.marginL
        spacing: Style.marginM

        RowLayout {
          Layout.fillWidth: true

          ColumnLayout {
            Layout.fillWidth: true
            spacing: Style.marginXXS

            NText {
              Layout.fillWidth: true
              text: monitorCard.screenName
              pointSize: Style.fontSizeM
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
            }

            NText {
              text: {
                return I18n.tr("system.monitor-description", {
                                 "model": monitorCard.modelData.model || I18n.tr("common.unknown"),
                                 "width": Math.round(monitorCard.modelData.width * monitorCard.compositorScale),
                                 "height": Math.round(monitorCard.modelData.height * monitorCard.compositorScale),
                                 "scale": monitorCard.compositorScale
                               });
              }
              pointSize: Style.fontSizeS
              color: Color.mOnSurfaceVariant
            }
          }

          NToggle {
            Layout.fillWidth: true
            checked: true
            enabled: false
          }
        }
      }
    }
  }
}
