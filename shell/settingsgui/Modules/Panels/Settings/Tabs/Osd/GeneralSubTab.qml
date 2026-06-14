import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: GlobalConfig.osd.* (osdconfig.hpp). ryoku's OSD has no position,
// overlay-layer, background-opacity or per-monitor config, so those upstream stubs
// were dropped. Per-event toggles live in the Events subtab.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    // RYOKU WIRED: GlobalConfig.osd.enabled (osd/Wrapper.qml gate)
    Layout.fillWidth: true
    label: I18n.tr("panels.osd.enabled-label")
    description: I18n.tr("panels.osd.enabled-description")
    checked: GlobalConfig.osd.enabled
    onToggled: checked => {
                 GlobalConfig.osd.enabled = checked;
                 GlobalConfig.save();
               }
  }

  NValueSlider {
    // RYOKU WIRED: GlobalConfig.osd.hideDelay (ms; osd/Wrapper.qml hide timer)
    Layout.fillWidth: true
    enabled: GlobalConfig.osd.enabled
    opacity: enabled ? 1.0 : 0.45
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
}
