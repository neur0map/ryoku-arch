import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Services.Compositor
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // The toggle is checked when the bar shows on that monitor.
  function isExcluded(name) {
    const ex = GlobalConfig.bar.excludedScreens || [];
    for (var i = 0; i < ex.length; i++) {
      if (ex[i] === name)
        return true;
    }
    return false;
  }

  function setShown(name, shown) {
    const ex = (GlobalConfig.bar.excludedScreens || []).slice();
    const idx = ex.indexOf(name);
    if (!shown && idx === -1)
      ex.push(name);
    else if (shown && idx !== -1)
      ex.splice(idx, 1);
    GlobalConfig.bar.excludedScreens = ex;
    GlobalConfig.save();
  }

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
            checked: !root.isExcluded(monitorCard.screenName)
            onToggled: checked => root.setShown(monitorCard.screenName, checked)
          }
        }
      }
    }
  }
}
