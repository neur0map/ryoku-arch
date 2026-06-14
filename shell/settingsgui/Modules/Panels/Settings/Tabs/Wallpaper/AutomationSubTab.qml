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

  // RYOKU WIRED: GlobalConfig.wallpaper.automationEnabled / wallpaperChangeMode /
  // randomIntervalSec. The actual rotation runs in qs.modules.WallpaperRotation
  // (always-loaded), which picks the next wallpaper and applies it through ryoku's
  // Wallpapers service. These settings persist in the settings-gui settings.json.

  NToggle {
    label: I18n.tr("panels.wallpaper.automation-scheduled-change-label")
    description: I18n.tr("panels.wallpaper.automation-scheduled-change-description")
    checked: GlobalConfig.wallpaper.automationEnabled
    onToggled: checked => {
      GlobalConfig.wallpaper.automationEnabled = checked;
      GlobalConfig.save();
    }
  }

  ColumnLayout {
    spacing: Style.marginL
    Layout.fillWidth: true
    enabled: GlobalConfig.wallpaper.automationEnabled

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
      currentKey: GlobalConfig.wallpaper.wallpaperChangeMode
      onSelected: key => {
        GlobalConfig.wallpaper.wallpaperChangeMode = key;
        GlobalConfig.save();
      }
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
      value: Math.max(1, Math.round(GlobalConfig.wallpaper.randomIntervalSec / 60))
      onValueChanged: {
        const seconds = value * 60;
        if (GlobalConfig.wallpaper.randomIntervalSec !== seconds) {
          GlobalConfig.wallpaper.randomIntervalSec = seconds;
          GlobalConfig.save();
        }
      }
    }
  }
}
