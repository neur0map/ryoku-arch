import QtQuick
import "../"
import "../services"

Rectangle {
  id: root

  property bool open: false
  property var service: WallpaperService

  signal closeRequested()

  visible: open
  opacity: open ? 1 : 0
  color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.96)
  border.width: 1
  border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.28)
  clip: true

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Column {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    Row {
      width: parent.width
      spacing: 8

      SkwdButton {
        label: "Monitor"
        active: root.service.selectedMonitor !== ""
        interactive: false
      }

      SkwdButton {
        label: "All"
        active: root.service.selectedMonitor === ""
        onClicked: {
          root.service.setSetting("selectedMonitor", "")
          root.closeRequested()
        }
      }

      SkwdButton {
        label: "Primary"
        active: root.service.selectedMonitor === "primary"
        onClicked: {
          root.service.setSetting("selectedMonitor", "primary")
          root.closeRequested()
        }
      }

      SkwdButton {
        label: "Close"
        onClicked: root.closeRequested()
      }
    }

    Flow {
      width: parent.width
      spacing: 10

      Repeater {
        model: ["eDP-1", "DP-1", "HDMI-A-1"]

        SkwdButton {
          label: modelData
          active: root.service.selectedMonitor === modelData
          onClicked: {
            root.service.setSetting("selectedMonitor", modelData)
            root.closeRequested()
          }
        }
      }
    }

    Text {
      width: parent.width
      text: root.service.selectedMonitor === ""
        ? "Wallpaper applies to all monitors."
        : "Wallpaper applies to " + root.service.selectedMonitor + "."
      color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.56)
      font.pixelSize: 12
      wrapMode: Text.WordWrap
    }
  }
}
