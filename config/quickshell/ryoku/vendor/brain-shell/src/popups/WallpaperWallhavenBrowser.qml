import QtQuick
import QtQuick.Controls
import "../"
import "../services"

Item {
  id: root

  property bool open: false
  property var service: WallpaperService
  signal closeRequested()

  opacity: open ? 1 : 0
  visible: open || opacity > 0

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(0, 0, 0, 0.64)
  }

  Column {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 12

    Row {
      width: parent.width
      spacing: 8

      Item {
        id: searchBox
        width: parent.width - closeButton.width - parent.spacing
        height: 30
        property int skew: 12

        Canvas {
          anchors.fill: parent
          property color strokeColor: searchInput.activeFocus ? Theme.active : Qt.rgba(1, 1, 1, 0.16)
          onStrokeColorChanged: requestPaint()
          onWidthChanged: requestPaint()
          onHeightChanged: requestPaint()
          onPaint: {
            var ctx = getContext("2d")
            var sk = searchBox.skew
            ctx.clearRect(0, 0, width, height)
            ctx.fillStyle = Qt.rgba(1, 1, 1, 0.075)
            ctx.beginPath()
            ctx.moveTo(sk, 0)
            ctx.lineTo(width, 0)
            ctx.lineTo(width - sk, height)
            ctx.lineTo(0, height)
            ctx.closePath()
            ctx.fill()
            ctx.strokeStyle = strokeColor
            ctx.lineWidth = 1
            ctx.stroke()
          }
        }

        Text {
          anchors.left: parent.left
          anchors.leftMargin: searchBox.skew + 8
          anchors.verticalCenter: parent.verticalCenter
          text: "Search wallhaven.cc"
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.34)
          font.pixelSize: 12
          visible: searchInput.text === ""
        }

        TextInput {
          id: searchInput
          anchors.fill: parent
          anchors.leftMargin: searchBox.skew + 8
          anchors.rightMargin: searchBox.skew + 8
          color: Theme.text
          selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
          font.pixelSize: 13
          verticalAlignment: TextInput.AlignVCenter
          Keys.onReturnPressed: function(event) {
            root.service.searchWallhaven(searchInput.text, 1)
            event.accepted = true
          }
          Keys.onEscapePressed: root.closeRequested()
        }
      }

      SkwdButton {
        id: closeButton
        label: "Close"
        onClicked: root.closeRequested()
      }
    }

    GridView {
      id: results
      width: parent.width
      height: parent.height - y
      cellWidth: 184
      cellHeight: 122
      clip: true
      model: root.service.filteredModel

      delegate: Item {
        required property int index
        required property string path
        required property string thumb
        required property string source
        required property string name
        required property string type

        width: results.cellWidth
        height: results.cellHeight
        visible: source === "wallhaven"

        Rectangle {
          anchors.fill: parent
          anchors.margins: 5
          color: Qt.rgba(1, 1, 1, 0.05)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.14)
          clip: true

          Image {
            anchors.fill: parent
            source: thumb || path
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
          }

          Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 26
            color: Qt.rgba(0, 0, 0, 0.64)
            Text {
              anchors.fill: parent
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              text: name
              color: Theme.text
              font.pixelSize: 10
              verticalAlignment: Text.AlignVCenter
              elide: Text.ElideRight
            }
          }
        }

        TapHandler {
          onTapped: root.service.applyItem({
            path: path,
            thumb: thumb,
            source: source,
            name: name,
            type: type
          })
        }
      }
    }
  }
}
