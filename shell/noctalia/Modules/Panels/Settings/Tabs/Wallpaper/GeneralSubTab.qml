import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Ryoku.Config
import qs.noctalia.Commons
import qs.noctalia.Services.Compositor
import qs.noctalia.Services.UI
import qs.noctalia.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  property var screen

  signal openMainFolderPicker
  signal openMonitorFolderPicker(string monitorName)

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

  ColumnLayout {
    // TODO: wire wallpaper panel open to ryoku launcher (no wallpaperPanel service in ryoku)
    // TODO: wire panelPosition, viewMode, directory, showHiddenFiles, enableMultiMonitorDirectories to ryoku
    enabled: false
    opacity: 0.45
    spacing: Style.marginL
    Layout.fillWidth: true

    RowLayout {

      NLabel {
        label: I18n.tr("tooltips.wallpaper-selector")
        description: I18n.tr("panels.wallpaper.settings-selector-description")
        Layout.alignment: Qt.AlignTop
      }

      NIconButton {
        icon: "wallpaper-selector"
        tooltipText: I18n.tr("tooltips.wallpaper-selector")
      }
    }

    NComboBox {
      label: I18n.tr("common.position")
      description: I18n.tr("panels.wallpaper.settings-selector-position-description")
      Layout.fillWidth: true
      model: []
      currentKey: ""
    }

    NComboBox {
      label: I18n.tr("panels.wallpaper.settings-view-mode-label")
      description: I18n.tr("panels.wallpaper.settings-view-mode-description")
      Layout.fillWidth: true
      model: []
      currentKey: ""
    }

    NTextInputButton {
      id: wallpaperPathInput
      label: I18n.tr("panels.wallpaper.settings-folder-label")
      description: I18n.tr("panels.wallpaper.settings-folder-description")
      text: ""
      buttonIcon: "folder-open"
      buttonTooltip: I18n.tr("panels.wallpaper.settings-folder-label")
      Layout.fillWidth: true
    }

    NToggle {
      // TODO: wire per-monitor wallpaper dirs to ryoku (single dir only: Paths.wallsdir)
      label: I18n.tr("panels.wallpaper.settings-monitor-specific-label")
      description: I18n.tr("panels.wallpaper.settings-monitor-specific-description")
      checked: false
    }
  }

  NDivider {
    Layout.fillWidth: true
  }

  NToggle {
    // TODO: wire to ryoku wallpaper cache (no useOriginalImages concept in ryoku)
    label: I18n.tr("panels.wallpaper.settings-use-original-images-label")
    description: I18n.tr("panels.wallpaper.settings-use-original-images-description")
    checked: false
    enabled: false
    opacity: 0.45
  }

  RowLayout {
    // TODO: wire clear-cache to ryoku (no ImageCacheService in ryoku)
    spacing: Style.marginM
    Layout.fillWidth: true
    enabled: false
    opacity: 0.45

    NLabel {
      label: I18n.tr("panels.wallpaper.settings-clear-cache-label")
      description: I18n.tr("panels.wallpaper.settings-clear-cache-description")
      Layout.fillWidth: true
    }

    NButton {
      icon: "trash"
      text: I18n.tr("panels.wallpaper.settings-clear-cache-button")
      outlined: true
    }
  }

  ColumnLayout {
    // TODO: wire overview wallpaper to ryoku (no overview wallpaper in ryoku)
    visible: false
    enabled: false
    opacity: 0.45
    spacing: Style.marginL
    Layout.fillWidth: true

    NToggle {
      label: I18n.tr("panels.wallpaper.settings-enable-overview-label")
      description: I18n.tr("panels.wallpaper.settings-enable-overview-description")
      checked: false
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.wallpaper.settings-overview-blur-strength-label")
      description: I18n.tr("panels.wallpaper.settings-overview-blur-strength-description")
      from: 0.0
      to: 1.0
      stepSize: 0.01
      value: 0
      text: "0%"
    }

    NValueSlider {
      Layout.fillWidth: true
      label: I18n.tr("panels.wallpaper.settings-overview-tint-label")
      description: I18n.tr("panels.wallpaper.settings-overview-tint-description")
      from: 0.0
      to: 1.0
      stepSize: 0.01
      value: 0
      text: "0%"
    }
  }
}
