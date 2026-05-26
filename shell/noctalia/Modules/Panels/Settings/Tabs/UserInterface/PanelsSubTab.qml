import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  enabled: false
  opacity: 0.45

  // TODO: wire panels UI controls to ryoku (no panelsAttachedToBar, allowPanelsOnScreenWithoutBar,
  //   panelBackgroundOpacity, dimmerOpacity, settingsPanelMode, settingsPanelSideBarCardStyle config in ryoku)

  NToggle {
    label: I18n.tr("panels.user-interface.panels-attached-to-bar-label")
    description: I18n.tr("panels.user-interface.panels-attached-to-bar-description")
    checked: true
  }

  NToggle {
    label: I18n.tr("panels.user-interface.allow-panels-without-bar-label")
    description: I18n.tr("panels.user-interface.allow-panels-without-bar-description")
    checked: false
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.user-interface.panel-background-opacity-label")
    description: I18n.tr("panels.user-interface.panel-background-opacity-description")
    from: 0
    to: 1
    stepSize: 0.01
    value: 1.0
    text: "100%"
  }

  NValueSlider {
    Layout.fillWidth: true
    label: I18n.tr("panels.user-interface.dimmer-opacity-label")
    description: I18n.tr("panels.user-interface.dimmer-opacity-description")
    from: 0
    to: 1
    stepSize: 0.01
    value: 0.5
    text: "50%"
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: I18n.tr("panels.user-interface.settings-panel-header")
  }

  NComboBox {
    label: I18n.tr("panels.user-interface.settings-panel-mode-label")
    description: I18n.tr("panels.user-interface.settings-panel-mode-description")
    Layout.fillWidth: true
    model: [
      {
        "key": "attached",
        "name": I18n.tr("options.settings-panel-mode.attached")
      }
    ]
    currentKey: "attached"
  }

  NToggle {
    label: I18n.tr("panels.user-interface.settings-panel-sidebar-card-style-label")
    description: I18n.tr("panels.user-interface.settings-panel-sidebar-card-style-description")
    checked: false
  }
}
