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

  NCheckbox {
    // RYOKU WIRED: GlobalConfig.utilities.toasts.nowPlaying (utilitiesconfig.hpp:28)
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.toast-media-label")
    description: I18n.tr("panels.notifications.toast-media-description")
    checked: GlobalConfig.utilities.toasts.nowPlaying
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.nowPlaying = checked;
                 GlobalConfig.save();
               }
  }

  NCheckbox {
    // RYOKU WIRED: GlobalConfig.utilities.toasts.kbLayoutChanged (utilitiesconfig.hpp:25)
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.toast-keyboard-label")
    description: I18n.tr("panels.notifications.toast-keyboard-description")
    checked: GlobalConfig.utilities.toasts.kbLayoutChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.kbLayoutChanged = checked;
                 GlobalConfig.save();
               }
  }

  NCheckbox {
    // RYOKU WIRED: GlobalConfig.utilities.toasts.chargingChanged (utilitiesconfig.hpp:18)
    Layout.fillWidth: true
    label: I18n.tr("panels.notifications.toast-battery-label")
    description: I18n.tr("panels.notifications.toast-battery-description")
    checked: GlobalConfig.utilities.toasts.chargingChanged
    onToggled: checked => {
                 GlobalConfig.utilities.toasts.chargingChanged = checked;
                 GlobalConfig.save();
               }
  }
}
