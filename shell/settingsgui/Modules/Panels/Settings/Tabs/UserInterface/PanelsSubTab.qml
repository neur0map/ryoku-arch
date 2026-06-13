import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NToggle {
    // TODO: ryoku panels are not bar-attached / floating like upstream — there is
    //   no panelsAttachedToBar backend, so this stays a disabled preview.
    label: I18n.tr("panels.user-interface.panels-attached-to-bar-label")
    description: I18n.tr("panels.user-interface.panels-attached-to-bar-description")
    checked: true
    enabled: false
    opacity: 0.45
  }

  NToggle {
    // TODO: no allowPanelsOnScreenWithoutBar backend in ryoku.
    label: I18n.tr("panels.user-interface.allow-panels-without-bar-label")
    description: I18n.tr("panels.user-interface.allow-panels-without-bar-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  // RYOKU: "Panel background opacity" intentionally omitted — ryoku already exposes
  // it as User Interface > Appearance > "Panel opacity" (appearance.transparency.base).
  // A second control here would edit the same value, so it is removed.

  NValueSlider {
    // RYOKU WIRED: GlobalConfig.appearance.dimmerOpacity drives the dim scrim
    // behind the session menu / detached popouts (drawers/ContentWindow.qml).
    Layout.fillWidth: true
    label: I18n.tr("panels.user-interface.dimmer-opacity-label")
    description: I18n.tr("panels.user-interface.dimmer-opacity-description")
    from: 0
    to: 1
    stepSize: 0.01
    value: GlobalConfig.appearance.dimmerOpacity
    text: Math.round(GlobalConfig.appearance.dimmerOpacity * 100) + "%"
    onMoved: value => {
      GlobalConfig.appearance.dimmerOpacity = value;
      GlobalConfig.save();
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: I18n.tr("panels.user-interface.settings-panel-header")
  }

  NComboBox {
    // TODO: ryoku only supports the attached settings layout — no centered / window mode yet.
    label: I18n.tr("panels.user-interface.settings-panel-mode-label")
    description: I18n.tr("panels.user-interface.settings-panel-mode-description")
    Layout.fillWidth: true
    enabled: false
    opacity: 0.45
    model: [
      {
        "key": "attached",
        "name": I18n.tr("options.settings-panel-mode.attached")
      }
    ]
    currentKey: "attached"
  }

  NToggle {
    // RYOKU WIRED: Settings.data.ui.settingsPanelSideBarCardStyle — the settings
    // panel sidebar (SettingsContent.qml) wraps itself in a filled rounded card
    // when this is on.
    label: I18n.tr("panels.user-interface.settings-panel-sidebar-card-style-label")
    description: I18n.tr("panels.user-interface.settings-panel-sidebar-card-style-description")
    checked: Settings.data.ui.settingsPanelSideBarCardStyle
    onToggled: checked => Settings.data.ui.settingsPanelSideBarCardStyle = checked
  }
}
