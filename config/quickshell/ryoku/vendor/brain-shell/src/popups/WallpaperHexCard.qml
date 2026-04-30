import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../"

Item {
  id: root

  required property var itemData
  property bool selected: false
  signal activated()

  width: 156
  height: 136

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
      color: Qt.rgba(0, 0, 0, root.selected ? 0.05 : 0.24)
    }
  }

  Shape {
    id: hexMask
    anchors.fill: parent
    visible: false
    layer.enabled: true
    ShapePath {
      fillColor: "white"
      strokeColor: "transparent"
      startX: width
      startY: height / 2
      PathLine { x: width * 0.75; y: 0 }
      PathLine { x: width * 0.25; y: 0 }
      PathLine { x: 0; y: height / 2 }
      PathLine { x: width * 0.25; y: height }
      PathLine { x: width * 0.75; y: height }
      PathLine { x: width; y: height / 2 }
    }
  }

  MultiEffect {
    anchors.fill: parent
    source: imageContent
    maskEnabled: true
    maskSource: hexMask
    maskThresholdMin: 0.3
    maskSpreadAtMin: 0.3
  }

  Shape {
    anchors.fill: parent
    ShapePath {
      fillColor: "transparent"
      strokeColor: root.selected ? Theme.active : Qt.rgba(1, 1, 1, 0.18)
      strokeWidth: root.selected ? 3 : 1
      startX: width
      startY: height / 2
      PathLine { x: width * 0.75; y: 0 }
      PathLine { x: width * 0.25; y: 0 }
      PathLine { x: 0; y: height / 2 }
      PathLine { x: width * 0.25; y: height }
      PathLine { x: width * 0.75; y: height }
      PathLine { x: width; y: height / 2 }
    }
  }

  TapHandler { onTapped: root.activated() }
}
