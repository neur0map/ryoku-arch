import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.noctalia.Commons
import qs.noctalia.Widgets

// RYOKU: Hyprland (window manager) settings. ryoku edits Hyprland's appearance
// and behavior with the external Hyprmod GUI rather than in-panel controls, so
// this tab links out to it (launched via ryoku-launch-hyprmod) plus a reload action.
ColumnLayout {
  id: root
  spacing: Style.marginL
  Layout.fillWidth: true

  NHeader {
    label: "Hyprland"
    description: "Window manager appearance and behavior"
  }

  NText {
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
    color: Color.mOnSurfaceVariant
    text: "Hyprland window-manager settings — window opacity, blur, drop shadows, corner rounding, gaps, borders and animations — are configured visually with Hyprmod. Changes are saved to ~/.config/hypr/hyprland-gui.conf and applied automatically."
  }

  RowLayout {
    Layout.topMargin: Style.marginS
    spacing: Style.marginM

    NButton {
      icon: "external-link"
      text: "Open Hyprmod"
      onClicked: Quickshell.execDetached(["ryoku-launch-hyprmod"])
    }

    NButton {
      icon: "refresh"
      text: "Reload Hyprland"
      outlined: true
      onClicked: Quickshell.execDetached(["ryoku-reload-hyprland"])
    }
  }

  Item {
    Layout.fillWidth: true
    Layout.fillHeight: true
  }
}
