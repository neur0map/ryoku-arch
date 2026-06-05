import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.settingsgui.Commons
import qs.settingsgui.Services.UI
import qs.settingsgui.Widgets

// RYOKU: Hyprland (window manager) settings. ryoku edits Hyprland's appearance and
// behavior with the external Hyprmod GUI rather than in-panel controls, so this tab
// links out to it (ryoku-launch-hyprmod). The settings it covers are listed below and
// registered as search entries (SettingsSearchService.hyprmodKeys) so searching e.g.
// "cursor" or "ring" lands here.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NHeader {
    label: I18n.tr("panels.hyprland.title")
    description: I18n.tr("panels.hyprland.description")
  }

  NText {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    text: I18n.tr("panels.hyprland.intro")
  }

  RowLayout {
    Layout.topMargin: Style.marginS
    spacing: Style.marginM

    NButton {
      icon: "external-link"
      text: I18n.tr("panels.hyprland.open-hyprmod")
      onClicked: Quickshell.execDetached(["ryoku-launch-hyprmod"])
    }

    NButton {
      icon: "refresh"
      text: I18n.tr("panels.hyprland.reload")
      outlined: true
      onClicked: Quickshell.execDetached(["ryoku-reload-hyprland"])
    }
  }

  NDivider {
    Layout.fillWidth: true
    Layout.topMargin: Style.marginS
  }

  NLabel {
    label: I18n.tr("panels.hyprland.items-header")
  }

  ColumnLayout {
    Layout.fillWidth: true
    Layout.leftMargin: Style.marginS
    spacing: Style.marginM

    Repeater {
      model: SettingsSearchService.hyprmodKeys

      NLabel {
        required property string modelData
        Layout.fillWidth: true
        label: I18n.tr("panels.hyprland.items." + modelData)
        description: I18n.tr("panels.hyprland.items." + modelData + "-desc")
      }
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
  }
}
