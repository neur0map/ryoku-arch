import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Ryoku.Config
import qs.settingsgui.Commons
import qs.settingsgui.Widgets

// RYOKU WIRED: GlobalConfig.gameMode.* (gamemodeconfig.hpp). One toggle per key;
// the game mode toggle itself lives in the shell frame's Quick Toggles (and
// `ryoku-shell ipc gameMode toggle`). Writes use explicit property assignment
// (bracket-indexed writes on the C++ config object are unreliable).
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NHeader {
    label: I18n.tr("panels.game-mode.title")
    description: I18n.tr("panels.game-mode.description")
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.hyprland-visuals-label")
    description: I18n.tr("panels.game-mode.hyprland-visuals-description")
    checked: GlobalConfig.gameMode.hyprlandVisuals
    onToggled: checked => {
                 GlobalConfig.gameMode.hyprlandVisuals = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.vrr-label")
    description: I18n.tr("panels.game-mode.vrr-description")
    checked: GlobalConfig.gameMode.vrr
    onToggled: checked => {
                 GlobalConfig.gameMode.vrr = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.direct-scanout-label")
    description: I18n.tr("panels.game-mode.direct-scanout-description")
    checked: GlobalConfig.gameMode.directScanout
    onToggled: checked => {
                 GlobalConfig.gameMode.directScanout = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.shell-animations-label")
    description: I18n.tr("panels.game-mode.shell-animations-description")
    checked: GlobalConfig.gameMode.shellAnimations
    onToggled: checked => {
                 GlobalConfig.gameMode.shellAnimations = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.dnd-label")
    description: I18n.tr("panels.game-mode.dnd-description")
    checked: GlobalConfig.gameMode.dnd
    onToggled: checked => {
                 GlobalConfig.gameMode.dnd = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.idle-inhibit-label")
    description: I18n.tr("panels.game-mode.idle-inhibit-description")
    checked: GlobalConfig.gameMode.idleInhibit
    onToggled: checked => {
                 GlobalConfig.gameMode.idleInhibit = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.night-light-off-label")
    description: I18n.tr("panels.game-mode.night-light-off-description")
    checked: GlobalConfig.gameMode.nightLightOff
    onToggled: checked => {
                 GlobalConfig.gameMode.nightLightOff = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.pause-wallpaper-label")
    description: I18n.tr("panels.game-mode.pause-wallpaper-description")
    checked: GlobalConfig.gameMode.pauseWallpaper
    onToggled: checked => {
                 GlobalConfig.gameMode.pauseWallpaper = checked;
                 GlobalConfig.save();
               }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.hardware-perf-label")
    description: I18n.tr("panels.game-mode.hardware-perf-description")
    checked: GlobalConfig.gameMode.hardwarePerf
    onToggled: checked => {
                 GlobalConfig.gameMode.hardwarePerf = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.nvidia-clock-lock-label")
    description: I18n.tr("panels.game-mode.nvidia-clock-lock-description")
    checked: GlobalConfig.gameMode.nvidiaClockLock
    onToggled: checked => {
                 GlobalConfig.gameMode.nvidiaClockLock = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.auto-detect-label")
    description: I18n.tr("panels.game-mode.auto-detect-description")
    checked: GlobalConfig.gameMode.autoDetect
    onToggled: checked => {
                 GlobalConfig.gameMode.autoDetect = checked;
                 GlobalConfig.save();
               }
  }
  NToggle {
    Layout.fillWidth: true
    label: I18n.tr("panels.game-mode.hide-panels-label")
    description: I18n.tr("panels.game-mode.hide-panels-description")
    checked: GlobalConfig.gameMode.hidePanels
    onToggled: checked => {
                 GlobalConfig.gameMode.hidePanels = checked;
                 GlobalConfig.save();
               }
  }
}
