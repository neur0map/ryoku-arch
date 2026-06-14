import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

// RYOKU WIRED: notification appearance/behaviour backed by Notifs.dnd and
// GlobalConfig.notifs.* (notifsconfig.hpp). The upstream master-enable, density,
// position, always-on-top, background-opacity and per-monitor controls were
// dropped here because the Ryoku notification backend has no equivalent for them.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    // RYOKU WIRED: Notifs.dnd (Notifs.qml) — suppresses popups while enabled.
    Layout.fillWidth: true
    label: I18n.tr("tooltips.do-not-disturb-enabled")
    description: I18n.tr("panels.notifications.settings-do-not-disturb-description")
    checked: Notifs.dnd
    onToggled: checked => {
                 Notifs.dnd = checked;
               }
  }

  NToggle {
    // RYOKU WIRED: GlobalConfig.notifs.openExpanded (notifsconfig.hpp)
    Layout.fillWidth: true
    label: qsTr("Open notifications expanded")
    description: qsTr("Show the full body and actions immediately instead of the collapsed preview.")
    checked: GlobalConfig.notifs.openExpanded
    onToggled: checked => {
                 GlobalConfig.notifs.openExpanded = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    // RYOKU WIRED: GlobalConfig.notifs.actionOnClick (notifsconfig.hpp)
    Layout.fillWidth: true
    label: qsTr("Click to run the default action")
    description: qsTr("A single click on a notification triggers its first action instead of only dismissing it.")
    checked: GlobalConfig.notifs.actionOnClick
    onToggled: checked => {
                 GlobalConfig.notifs.actionOnClick = checked;
                 GlobalConfig.save();
               }
  }

  NToggle {
    // RYOKU WIRED: GlobalConfig.notifs.fullscreen ("on"/"off") — gate popups while a
    // fullscreen window is focused (Notifs.shouldShowPopup()).
    Layout.fillWidth: true
    label: qsTr("Show notifications over fullscreen apps")
    description: qsTr("When off, popups are held back while a fullscreen window is focused and stay in history.")
    checked: GlobalConfig.notifs.fullscreen === "on"
    onToggled: checked => {
                 GlobalConfig.notifs.fullscreen = checked ? "on" : "off";
                 GlobalConfig.save();
               }
  }
}
