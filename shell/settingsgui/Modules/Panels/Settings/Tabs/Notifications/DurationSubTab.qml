import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: GlobalConfig.notifs.* (notifsconfig.hpp). ryoku has no per-urgency
// timeouts (the upstream low/normal/critical sliders were a fiction here), only a
// default timeout and a separate fullscreen timeout, so this reflects the real model.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    // RYOKU WIRED: GlobalConfig.notifs.expire — honour the timeout below (and any
    // app-provided expiry) instead of keeping popups until dismissed.
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.duration-respect-expire-label")
    description: I18n.tr("panels.notifications.duration-respect-expire-description")
    checked: GlobalConfig.notifs.expire
    onToggled: checked => {
                 GlobalConfig.notifs.expire = checked;
                 GlobalConfig.save();
               }
  }

  NValueSlider {
    // RYOKU WIRED: GlobalConfig.notifs.defaultExpireTimeout (ms; slider in seconds).
    Layout.fillWidth: true
    enabled: GlobalConfig.notifs.expire
    opacity: enabled ? 1.0 : 0.45
    label: qsTr("Dismiss after")
    description: qsTr("How long a popup stays on screen before it auto-dismisses to history.")
    from: 1
    to: 30
    stepSize: 1
    showReset: true
    value: Math.round(GlobalConfig.notifs.defaultExpireTimeout / 1000)
    onMoved: value => {
               GlobalConfig.notifs.defaultExpireTimeout = value * 1000;
               GlobalConfig.save();
             }
    text: Math.round(GlobalConfig.notifs.defaultExpireTimeout / 1000) + "s"
  }

  NValueSlider {
    // RYOKU WIRED: GlobalConfig.notifs.fullscreenExpireTimeout (ms; slider in seconds).
    // Used while a fullscreen window is focused; applies even when expire is off.
    Layout.fillWidth: true
    label: qsTr("Dismiss after (fullscreen)")
    description: qsTr("Shorter timeout used while a fullscreen window is focused.")
    from: 1
    to: 30
    stepSize: 1
    showReset: true
    value: Math.round(GlobalConfig.notifs.fullscreenExpireTimeout / 1000)
    onMoved: value => {
               GlobalConfig.notifs.fullscreenExpireTimeout = value * 1000;
               GlobalConfig.save();
             }
    text: Math.round(GlobalConfig.notifs.fullscreenExpireTimeout / 1000) + "s"
  }
}
