import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../"

Item {
  id: root

  required property var itemData
  property bool selected: false
  property int skewOffset: 16
  property int cardWidth: 174
  property int cardHeight: 110
  signal activated()

  width: root.cardWidth
  height: root.cardHeight
  scale: selected ? 1.0 : 0.965
  opacity: selected ? 1.0 : 0.86

  Behavior on scale { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: Theme.animDuration; easing.type: Easing.OutCubic } }

  readonly property string previewSource: mediaSource(root.itemData.thumb || root.itemData.path || "")

  function mediaSource(path) {
    if (!path || path === "") return ""
    if (path.indexOf("file://") === 0 || path.indexOf("http://") === 0 || path.indexOf("https://") === 0) return path
    return "file://" + path
  }

  Item {
    id: imageContent
    anchors.fill: parent
    visible: false

    Image {
      anchors.fill: parent
      source: root.previewSource
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, root.selected ? 0.04 : 0.22)
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
    anchors.fill: parent
    source: imageContent
    maskEnabled: true
    maskSource: maskShape
    maskThresholdMin: 0.3
    maskSpreadAtMin: 0.3
  }

  Shape {
    anchors.fill: parent
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.selected ? Theme.active : Qt.rgba(1, 1, 1, 0.16)
      strokeWidth: root.selected ? 3 : 1
      startX: root.skewOffset
      startY: 0
      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width - root.skewOffset; y: root.height }
      PathLine { x: 0; y: root.height }
      PathLine { x: root.skewOffset; y: 0 }
    }
  }

  HoverHandler { cursorShape: Qt.PointingHandCursor }
  TapHandler { onTapped: root.activated() }
}
