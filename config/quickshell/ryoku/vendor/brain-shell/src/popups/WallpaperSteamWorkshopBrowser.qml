import QtQuick
import QtQuick.Controls
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
        label: "Steam Workshop"
        active: root.service.steamEnabled
        interactive: false
      }

      SkwdButton {
        label: root.service.steamEnabled ? "Enabled" : "Enable In Settings"
        active: root.service.steamEnabled
        onClicked: root.service.setSetting("steamEnabled", !root.service.steamEnabled)
      }

      SkwdButton {
        label: "Close"
        onClicked: root.closeRequested()
      }
    }

    Item {
      width: parent.width
      height: 34
      property int skew: 10

      Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
          var ctx = getContext("2d")
          var sk = parent.skew
          ctx.clearRect(0, 0, width, height)
          ctx.fillStyle = Qt.rgba(1, 1, 1, 0.07)
          ctx.beginPath()
          ctx.moveTo(sk, 0)
          ctx.lineTo(width, 0)
          ctx.lineTo(width - sk, height)
          ctx.lineTo(0, height)
          ctx.closePath()
          ctx.fill()
          ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12)
          ctx.stroke()
        }
      }

      Text {
        anchors.left: parent.left
        anchors.leftMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        text: "Steam Workshop search is available when the Steam backend is configured."
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.62)
        font.pixelSize: 12
        elide: Text.ElideRight
        width: parent.width - 36
      }
    }

    Flow {
      width: parent.width
      spacing: 10

      InfoTile { label: "Wallpaper Engine"; value: root.service.steamEnabled ? "Workshop browser enabled" : "Disabled" }
      InfoTile { label: "Steam root"; value: root.service.steamRoot }
      InfoTile { label: "Steam user"; value: root.service.steamUsername !== "" ? root.service.steamUsername : "not set" }
      InfoTile { label: "API key"; value: root.service.steamApiKey !== "" ? "configured" : "not set" }
    }
  }

  component InfoTile: Item {
    property string label: ""
    property string value: ""

    width: 210
    height: 54

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(1, 1, 1, 0.055)
      border.width: 1
      border.color: Qt.rgba(1, 1, 1, 0.10)
    }

    Column {
      anchors.fill: parent
      anchors.margins: 10
      spacing: 5

      Text {
        width: parent.width
        text: label
        color: Theme.text
        font.pixelSize: 11
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: value
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.48)
        font.pixelSize: 10
        elide: Text.ElideMiddle
      }
    }
  }
}
