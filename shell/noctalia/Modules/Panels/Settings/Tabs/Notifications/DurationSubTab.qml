import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    // RYOKU WIRED: GlobalConfig.notifs.expire (notifsconfig.hpp:13) — respect app-provided expiry
    label: I18n.tr("panels.notifications.duration-respect-expire-label")
    description: I18n.tr("panels.notifications.duration-respect-expire-description")
    checked: GlobalConfig.notifs.expire
    onToggled: checked => {
                 GlobalConfig.notifs.expire = checked;
                 GlobalConfig.save();
               }
  }

  NValueSlider {
    // RYOKU WIRED: GlobalConfig.notifs.defaultExpireTimeout (notifsconfig.hpp:16) maps to low/normal urgency (in ms, slider shows seconds)
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.duration-low-urgency-label")
    description: I18n.tr("panels.notifications.duration-low-urgency-description")
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
    // RYOKU WIRED: GlobalConfig.notifs.defaultExpireTimeout (ryoku has no per-urgency duration; low/normal share this value)
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.duration-normal-urgency-label")
    description: I18n.tr("panels.notifications.duration-normal-urgency-description")
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
    // RYOKU WIRED: GlobalConfig.notifs.fullscreenExpireTimeout (notifsconfig.hpp:16) — closest ryoku has to a shorter/critical duration
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.duration-critical-urgency-label")
    description: I18n.tr("panels.notifications.duration-critical-urgency-description")
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
