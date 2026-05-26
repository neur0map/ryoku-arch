import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true
  // TODO: wire automationEnabled, wallpaperChangeMode, randomIntervalSec to ryoku (no auto-change wallpaper in ryoku)
  enabled: false
  opacity: 0.45

  NToggle {
    label: I18n.tr("panels.wallpaper.automation-scheduled-change-label")
    description: I18n.tr("panels.wallpaper.automation-scheduled-change-description")
    checked: false
  }

  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true

    NComboBox {
      label: I18n.tr("panels.wallpaper.automation-change-mode-label")
      description: I18n.tr("panels.wallpaper.automation-change-mode-description")
      Layout.fillWidth: true
      model: [
        {
          "key": "random",
          "name": I18n.tr("common.random")
        },
        {
          "key": "alphabetical",
          "name": I18n.tr("panels.wallpaper.automation-change-mode-alphabetical")
        }
      ]
      currentKey: "random"
    }

    NSpinBox {
      label: I18n.tr("panels.wallpaper.automation-interval-label")
      description: I18n.tr("panels.wallpaper.automation-interval-description")
      Layout.fillWidth: true
      from: 1
      to: 1440
      stepSize: 1
      suffix: "m"
      value: 30
    }
  }
}
