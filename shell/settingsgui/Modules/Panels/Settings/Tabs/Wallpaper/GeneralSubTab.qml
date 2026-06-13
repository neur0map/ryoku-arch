import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets
import qs.services

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var screen

  signal openMainFolderPicker

  NToggle {
    // RYOKU WIRED: GlobalConfig.background.wallpaperEnabled (backgroundconfig.hpp:121)
    label: I18n.tr("panels.wallpaper.settings-enable-management-label")
    description: I18n.tr("panels.wallpaper.settings-enable-management-description")
    checked: GlobalConfig.background.wallpaperEnabled
    onToggled: checked => {
                 GlobalConfig.background.wallpaperEnabled = checked;
                 GlobalConfig.save();
               }
  }

  NDivider {
    Layout.fillWidth: true
  }

  // RYOKU WIRED: opens the main wallpaper selector, skwd-wall (the same picker
  // bound to Super+W). Runs ryoku-cmd-wallpaper-switcher, which starts the
  // skwd-daemon if needed then `skwd wall toggle`; the chosen wallpaper is routed
  // back through `ryoku wallpaper -f`, so ryoku stays authoritative for the
  // wallpaper layer and scheme.
  RowLayout {
    Layout.fillWidth: true
    spacing: Style.marginM

    NLabel {
      label: I18n.tr("tooltips.wallpaper-selector")
      description: I18n.tr("panels.wallpaper.settings-selector-description")
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
    }

    NButton {
      icon: "wallpaper-selector"
      text: I18n.tr("tooltips.wallpaper-selector")
      outlined: true
      onClicked: {
        Quickshell.execDetached(["sh", "-lc", "exec \"$HOME/.local/share/ryoku/bin/ryoku-cmd-wallpaper-switcher\""]);
        const vis = Visibilities.getForActive();
        if (vis)
          vis.settings = false;
      }
    }
  }

  NTextInputButton {
    // RYOKU WIRED: GlobalConfig.paths.wallpaperDir (userpaths.hpp:18) — the single
    // wallpaper directory ryoku scans (Paths.wallsdir resolves it to absolute).
    label: I18n.tr("panels.wallpaper.settings-folder-label")
    description: I18n.tr("panels.wallpaper.settings-folder-description")
    text: GlobalConfig.paths.wallpaperDir
    buttonIcon: "folder-open"
    buttonTooltip: I18n.tr("panels.wallpaper.settings-folder-label")
    Layout.fillWidth: true
    onButtonClicked: root.openMainFolderPicker()
    onInputEditingFinished: {
      if (text !== GlobalConfig.paths.wallpaperDir) {
        GlobalConfig.paths.wallpaperDir = text;
        GlobalConfig.save();
      }
    }
  }

  NSpinBox {
    // RYOKU WIRED: GlobalConfig.launcher.maxWallpapers (launcherconfig.hpp:35) —
    // how many wallpapers the launcher carousel shows.
    label: I18n.tr("panels.wallpaper.settings-selector-max-label")
    description: I18n.tr("panels.wallpaper.settings-selector-max-description")
    Layout.fillWidth: true
    from: 1
    to: 50
    stepSize: 1
    value: GlobalConfig.launcher.maxWallpapers
    onValueChanged: {
      if (GlobalConfig.launcher.maxWallpapers !== value) {
        GlobalConfig.launcher.maxWallpapers = value;
        GlobalConfig.save();
      }
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NHeader {
    label: I18n.tr("panels.wallpaper.live-title")
  }

  NToggle {
    label: I18n.tr("panels.wallpaper.live-enabled-label")
    description: I18n.tr("panels.wallpaper.live-enabled-description")
    checked: GlobalConfig.wallpaper.liveWallpaperEnabled ?? true
    onToggled: checked => {
      GlobalConfig.wallpaper.liveWallpaperEnabled = checked;
      GlobalConfig.save();
    }
  }

  NToggle {
    label: I18n.tr("panels.wallpaper.live-muted-label")
    description: I18n.tr("panels.wallpaper.live-muted-description")
    checked: GlobalConfig.wallpaper.videoMuted ?? true
    onToggled: checked => {
      GlobalConfig.wallpaper.videoMuted = checked;
      GlobalConfig.save();
    }
  }

  NSpinBox {
    label: I18n.tr("panels.wallpaper.live-fps-cap-label")
    description: I18n.tr("panels.wallpaper.live-fps-cap-description")
    Layout.fillWidth: true
    from: 24
    to: 144
    stepSize: 1
    suffix: " fps"
    value: GlobalConfig.wallpaper.videoFpsCap ?? 60
    onValueChanged: {
      if ((GlobalConfig.wallpaper.videoFpsCap ?? 60) !== value) {
        GlobalConfig.wallpaper.videoFpsCap = value;
        GlobalConfig.save();
      }
    }
  }

  NToggle {
    label: I18n.tr("panels.wallpaper.live-pause-on-fullscreen-label")
    description: I18n.tr("panels.wallpaper.live-pause-on-fullscreen-description")
    checked: GlobalConfig.wallpaper.pauseOnFullscreen ?? true
    onToggled: checked => {
      GlobalConfig.wallpaper.pauseOnFullscreen = checked;
      GlobalConfig.save();
    }
  }

  NComboBox {
    label: I18n.tr("panels.wallpaper.live-transition-label")
    description: I18n.tr("panels.wallpaper.live-transition-description")
    Layout.fillWidth: true
    model: [
      { "key": "any",    "name": "Any" },
      { "key": "none",   "name": "None" },
      { "key": "simple", "name": "Simple" },
      { "key": "fade",   "name": "Fade" },
      { "key": "wipe",   "name": "Wipe" },
      { "key": "grow",   "name": "Grow" },
      { "key": "center", "name": "Center" },
      { "key": "outer",  "name": "Outer" },
      { "key": "random", "name": "Random" }
    ]
    currentKey: GlobalConfig.wallpaper.swwwTransition ?? "any"
    onSelected: key => {
      GlobalConfig.wallpaper.swwwTransition = key;
      GlobalConfig.save();
    }
  }
}
