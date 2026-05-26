import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var addMonitor
  property var removeMonitor

  NComboBox {
    // TODO: wire OSD position to ryoku (position hardcoded in osd/Wrapper.qml)
    label: I18n.tr("common.position")
    description: I18n.tr("panels.osd.location-description")
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "top_right",
        "name": I18n.tr("positions.top-right")
      }
    ]
    currentKey: "top_right"
  }

  NToggle {
    // RYOKU WIRED: GlobalConfig.osd.enabled (osdconfig.hpp:11)
    label: I18n.tr("panels.osd.enabled-label")
    description: I18n.tr("panels.osd.enabled-description")
    checked: GlobalConfig.osd.enabled
    onToggled: checked => {
                 GlobalConfig.osd.enabled = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    // TODO: wire OSD overlay layer to ryoku (no overlayLayer config in ryoku osd)
    label: I18n.tr("panels.osd.always-on-top-label")
    description: I18n.tr("panels.osd.always-on-top-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  NValueSlider {
    // TODO: wire OSD background opacity to ryoku (no backgroundOpacity config in ryoku osd)
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.background-opacity-label")
    description: I18n.tr("panels.osd.background-opacity-description")
    from: 0
    to: 100
    stepSize: 1
    value: 100
    text: "100%"
    enabled: false
    opacity: 0.45
  }

  NValueSlider {
    // RYOKU WIRED: GlobalConfig.osd.hideDelay (osdconfig.hpp:12) — in ms
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.duration-auto-hide-label")
    description: I18n.tr("panels.osd.duration-auto-hide-description")
    from: 500
    to: 5000
    stepSize: 100
    showReset: true
    value: GlobalConfig.osd.hideDelay
    onMoved: value => {
               GlobalConfig.osd.hideDelay = value;
               GlobalConfig.save();
             }
    text: Math.round(GlobalConfig.osd.hideDelay / 1000 * 10) / 10 + "s"
  }

  NDivider {
    Layout.fillWidth: true
  }

  NText {
    // TODO: wire OSD per-monitor selection to ryoku (no per-monitor OSD config)
    text: I18n.tr("panels.osd.monitors-desc")
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
    opacity: 0.45
  }

  Repeater {
    // TODO: wire per-monitor OSD to ryoku
    model: Quickshell.screens || []
    delegate: NCheckbox {
      Layout.fillWidth: true
      readonly property real compositorScale: {
        const info = CompositorService.displayScales[modelData.name];
        return (info && info.scale) ? info.scale : 1.0;
      }
      label: modelData.name || I18n.tr("common.unknown")
      description: {
        I18n.tr("system.monitor-description", {
                  "model": modelData.model,
                  "width": modelData.width * compositorScale,
                  "height": modelData.height * compositorScale,
                  "scale": compositorScale
                });
      }
      checked: false
      enabled: false
      opacity: 0.45
    }
  }
}
