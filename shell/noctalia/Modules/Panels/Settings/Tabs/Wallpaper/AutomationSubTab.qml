import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.noctalia.Commons
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  // RYOKU WIRED: Settings.data.wallpaper.automationEnabled / wallpaperChangeMode /
  // randomIntervalSec. The actual rotation runs in qs.modules.WallpaperRotation
  // (always-loaded), which picks the next wallpaper and applies it through ryoku's
  // Wallpapers service. These settings persist in Noctalia's settings.json.

  NToggle {
    label: I18n.tr("panels.wallpaper.automation-scheduled-change-label")
    description: I18n.tr("panels.wallpaper.automation-scheduled-change-description")
    checked: Settings.data.wallpaper.automationEnabled
    onToggled: checked => Settings.data.wallpaper.automationEnabled = checked
  }

  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true
    enabled: Settings.data.wallpaper.automationEnabled

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
      currentKey: Settings.data.wallpaper.wallpaperChangeMode
      onSelected: key => Settings.data.wallpaper.wallpaperChangeMode = key
    }

    NSpinBox {
      // Stored as seconds (randomIntervalSec); displayed in minutes.
      label: I18n.tr("panels.wallpaper.automation-interval-label")
      description: I18n.tr("panels.wallpaper.automation-interval-description")
      Layout.fillWidth: true
      from: 1
      to: 1440
      stepSize: 1
      suffix: "m"
      value: Math.max(1, Math.round(Settings.data.wallpaper.randomIntervalSec / 60))
      onValueChanged: {
        const seconds = value * 60;
        if (Settings.data.wallpaper.randomIntervalSec !== seconds)
          Settings.data.wallpaper.randomIntervalSec = seconds;
      }
    }
  }
}
