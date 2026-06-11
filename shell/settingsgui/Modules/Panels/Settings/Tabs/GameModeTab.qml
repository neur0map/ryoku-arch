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

  // One NToggle per GlobalConfig.gameMode key; the toggle itself lives in the
  // shell frame's Quick Toggles (and `ryoku-shell ipc gameMode toggle`).
  component GameModeToggle: NToggle {
    required property string configKey
    Layout.fillWidth: true
    checked: GlobalConfig.gameMode[configKey]
    onToggled: checked => {
                 GlobalConfig.gameMode[configKey] = checked;
                 GlobalConfig.save();
               }
  }

  NHeader {
    label: I18n.tr("panels.game-mode.title")
    description: I18n.tr("panels.game-mode.description")
  }

  GameModeToggle {
    configKey: "hyprlandVisuals"
    label: I18n.tr("panels.game-mode.hyprland-visuals-label")
    description: I18n.tr("panels.game-mode.hyprland-visuals-description")
  }
  GameModeToggle {
    configKey: "vrr"
    label: I18n.tr("panels.game-mode.vrr-label")
    description: I18n.tr("panels.game-mode.vrr-description")
  }
  GameModeToggle {
    configKey: "directScanout"
    label: I18n.tr("panels.game-mode.direct-scanout-label")
    description: I18n.tr("panels.game-mode.direct-scanout-description")
  }
  GameModeToggle {
    configKey: "shellAnimations"
    label: I18n.tr("panels.game-mode.shell-animations-label")
    description: I18n.tr("panels.game-mode.shell-animations-description")
  }
  GameModeToggle {
    configKey: "dnd"
    label: I18n.tr("panels.game-mode.dnd-label")
    description: I18n.tr("panels.game-mode.dnd-description")
  }
  GameModeToggle {
    configKey: "idleInhibit"
    label: I18n.tr("panels.game-mode.idle-inhibit-label")
    description: I18n.tr("panels.game-mode.idle-inhibit-description")
  }
  GameModeToggle {
    configKey: "nightLightOff"
    label: I18n.tr("panels.game-mode.night-light-off-label")
    description: I18n.tr("panels.game-mode.night-light-off-description")
  }
  GameModeToggle {
    configKey: "pauseWallpaper"
    label: I18n.tr("panels.game-mode.pause-wallpaper-label")
    description: I18n.tr("panels.game-mode.pause-wallpaper-description")
  }

  NDivider {
    Layout.fillWidth: true
  }

  GameModeToggle {
    configKey: "hardwarePerf"
    label: I18n.tr("panels.game-mode.hardware-perf-label")
    description: I18n.tr("panels.game-mode.hardware-perf-description")
  }
  GameModeToggle {
    configKey: "nvidiaClockLock"
    label: I18n.tr("panels.game-mode.nvidia-clock-lock-label")
    description: I18n.tr("panels.game-mode.nvidia-clock-lock-description")
  }
  GameModeToggle {
    configKey: "autoDetect"
    label: I18n.tr("panels.game-mode.auto-detect-label")
    description: I18n.tr("panels.game-mode.auto-detect-description")
  }
  GameModeToggle {
    configKey: "hidePanels"
    label: I18n.tr("panels.game-mode.hide-panels-label")
    description: I18n.tr("panels.game-mode.hide-panels-description")
  }
}
