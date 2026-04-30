import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../"

// Slice behavior adapted from liixini/skwd-wall's MIT-licensed SliceDelegate.
Item {
  id: root

  required property var itemData
  property bool selected: false
  property bool hovered: false
  property int skewOffset: 22
  property int expandedWidth: 320
  property int hoverWidth: 204
  property int sliceWidth: 104
  signal activated()

  width: root.selected ? root.expandedWidth : (root.hovered ? root.hoverWidth : root.sliceWidth)
  height: 278
  z: root.selected ? 3 : (root.hovered ? 2 : 1)
  clip: false

  readonly property bool expanded: root.selected || root.hovered
  readonly property real mediaScale: root.selected ? 1.0 : (root.hovered ? 1.05 : 1.18)
  readonly property string previewSource: mediaSource(root.itemData.preview || "")
  readonly property string label: root.itemData.display || root.itemData.name || ""

  function mediaSource(path) {
    if (!path || path === "") return ""
    if (path.indexOf("file://") === 0 || path.indexOf("http://") === 0 || path.indexOf("https://") === 0) return path
    return "file://" + path
  }

  Behavior on width {
    NumberAnimation {
      duration: Theme.animDuration + 110
      easing.type: Easing.OutCubic
    }
  }

  Item {
    id: cardContent
    anchors.fill: parent
    visible: false

    Image {
      id: imagePreview
      anchors.fill: parent
      source: root.previewSource
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      scale: root.mediaScale
      transformOrigin: Item.Center
      visible: root.previewSource !== ""

      Behavior on scale {
        NumberAnimation {
          duration: Theme.animDuration + 90
          easing.type: Easing.OutCubic
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: root.previewSource === ""
        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16)
        : Qt.rgba(0, 0, 0, 0.12)
    }
  }

  Shape {
    id: maskShape
    anchors.fill: parent
    visible: false
    layer.enabled: true

    ShapePath {
      fillColor: "white"
      strokeColor: "transparent"
      startX: root.skewOffset
      startY: 0

      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width - root.skewOffset; y: root.height }
      PathLine { x: 0; y: root.height }
      PathLine { x: root.skewOffset; y: 0 }
    }
  }

  MultiEffect {
    source: cardContent
    anchors.fill: parent
    maskEnabled: true
    maskSource: maskShape
    maskThresholdMin: 0.3
    maskSpreadAtMin: 0.3
  }

  Shape {
    anchors.fill: parent

    ShapePath {
      fillColor: "transparent"
      strokeColor: root.selected
        ? Theme.active
        : (root.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.58) : Qt.rgba(1, 1, 1, 0.16))
      strokeWidth: root.selected ? 3 : (root.hovered ? 2 : 1)
      startX: root.skewOffset
      startY: 0

      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width - root.skewOffset; y: root.height }
      PathLine { x: 0; y: root.height }
      PathLine { x: root.skewOffset; y: 0 }
    }
  }

  Rectangle {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 46
    color: Qt.rgba(0, 0, 0, 0.62)
    clip: true

    Text {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      anchors.leftMargin: root.skewOffset + 10
      anchors.rightMargin: 10
      text: root.label
      color: Theme.text
      font.pixelSize: 11
      font.weight: Font.Medium
      horizontalAlignment: Text.AlignHCenter
      elide: Text.ElideRight
    }
  }

  Rectangle {
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.rightMargin: root.skewOffset + 8
    anchors.topMargin: 8
    width: activeLabel.implicitWidth + 14
    height: 20
    radius: 4
    color: Qt.rgba(0, 0, 0, 0.62)
    visible: root.itemData.active

    Text {
      id: activeLabel
      anchors.centerIn: parent
      text: "ACTIVE"
      color: Theme.active
      font.pixelSize: 9
      font.weight: Font.Bold
    }
  }

  HoverHandler {
    cursorShape: Qt.PointingHandCursor
    onHoveredChanged: root.hovered = hovered
  }

  TapHandler {
    onTapped: root.activated()
  }
}
