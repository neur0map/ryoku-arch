import QtQuick
import QtQuick.Controls
import Quickshell
import "../"
import "../services"

Rectangle {
  id: root

  property bool open: false
  readonly property string videoBackend: "mpvpaper"
  readonly property string videoStatus: WallpaperService.statusText !== "" ? WallpaperService.statusText : "Ready"

  signal closeRequested()

  width: open ? 340 : 0
  opacity: open ? 1 : 0
  radius: 8
  color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.94)
  border.width: 1
  border.color: Qt.rgba(1, 1, 1, 0.08)
  clip: true

  Behavior on width {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Behavior on opacity {
    NumberAnimation { duration: Theme.animDuration }
  }

  Column {
    anchors.fill: parent
    anchors.margins: root.open ? 16 : 0
    spacing: 12
    visible: root.open || root.width >= 40

    Text {
      text: "Settings"
      color: Theme.text
      font.pixelSize: 16
      font.weight: Font.Bold
    }

    Text {
      width: parent.width
      text: "Video: " + root.videoBackend
      color: Theme.text
      font.pixelSize: 12
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      text: "Status: " + (WallpaperService.cacheLoading ? "Rebuilding" : root.videoStatus)
      color: Theme.subtext
      font.pixelSize: 12
      elide: Text.ElideRight
    }

    Rectangle {
      width: parent.width
      height: 32
      radius: 6
      color: WallpaperService.cacheLoading ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18) : Qt.rgba(1, 1, 1, 0.08)

      Text {
        anchors.centerIn: parent
        text: WallpaperService.cacheLoading ? "Rebuilding" : "Rebuild Cache"
        color: WallpaperService.cacheLoading ? Theme.active : Theme.text
        font.pixelSize: 12
      }

      HoverHandler {
        cursorShape: WallpaperService.cacheLoading ? Qt.ArrowCursor : Qt.PointingHandCursor
      }

      TapHandler {
        onTapped: {
          if (WallpaperService.cacheLoading) return
          WallpaperService.rebuildCache()
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 32
      radius: 6
      color: Qt.rgba(1, 1, 1, 0.08)

      Text {
        anchors.centerIn: parent
        text: "Close"
        color: Theme.text
        font.pixelSize: 12
      }

      HoverHandler { cursorShape: Qt.PointingHandCursor }
      TapHandler {
        onTapped: root.closeRequested()
      }
    }
  }
}
