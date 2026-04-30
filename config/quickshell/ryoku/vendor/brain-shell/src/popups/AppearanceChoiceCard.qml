import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "../"

// Skewed panel styling adapted from liixini/skwd-wall's MIT-licensed controls.
Item {
  id: root

  required property var itemData
  property bool selected: false
  property bool hovered: false
  property string kind: "font"
  property int skewOffset: 20
  property int expandedWidth: 226
  property int compactWidth: 188
  signal activated()

  width: root.selected || root.hovered ? root.expandedWidth : root.compactWidth
  height: 258
  opacity: root.itemData.installed === false ? 0.72 : 1.0
  z: root.selected ? 3 : (root.hovered ? 2 : 1)

  readonly property string label: root.itemData.display || root.itemData.family || root.itemData.name || ""
  readonly property string detail: root.kind === "font"
    ? (root.itemData.family || "")
    : (root.itemData.name || "")
  readonly property string previewSource: mediaSource(root.itemData.preview || "")

  function mediaSource(path) {
    if (!path || path === "") return ""
    if (path.indexOf("file://") === 0 || path.indexOf("http://") === 0 || path.indexOf("https://") === 0) return path
    return "file://" + path
  }

  Behavior on width {
    NumberAnimation {
      duration: Theme.animDuration + 100
      easing.type: Easing.OutCubic
    }
  }

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Item {
    id: cardContent
    anchors.fill: parent
    visible: false

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      height: 144
      color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, root.selected ? 0.16 : 0.09)

      Image {
        anchors.fill: parent
        anchors.margins: root.kind === "cursor" ? 12 : 7
        source: root.previewSource
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        cache: true
        mipmap: true
        visible: root.previewSource !== ""
      }

      Text {
        anchors.centerIn: parent
        text: root.kind === "font" ? "Aa" : "↖"
        color: root.selected ? Theme.active : Theme.text
        font.family: root.kind === "font" && root.itemData.installed ? root.itemData.family : "sans-serif"
        font.pixelSize: root.kind === "font" ? 46 : 58
        font.weight: Font.Bold
        visible: root.previewSource === ""
      }
    }

    Column {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.topMargin: 160
      anchors.leftMargin: root.skewOffset + 10
      anchors.rightMargin: 14
      spacing: 7

      Text {
        width: parent.width
        text: root.label
        color: Theme.text
        font.pixelSize: 12
        font.weight: Font.Medium
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        text: root.detail
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
        font.pixelSize: 10
        elide: Text.ElideRight
      }
    }

    Rectangle {
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: root.skewOffset + 8
      anchors.topMargin: 8
      width: stateLabel.implicitWidth + 14
      height: 20
      radius: 4
      color: Qt.rgba(0, 0, 0, 0.58)

      Text {
        id: stateLabel
        anchors.centerIn: parent
        text: root.itemData.active ? "ACTIVE" : (root.itemData.installed ? "READY" : "INSTALL")
        color: root.itemData.active ? Theme.active : Theme.text
        font.pixelSize: 9
        font.weight: Font.Bold
      }
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
      fillColor: Qt.rgba(1, 1, 1, root.selected ? 0.035 : 0.015)
      strokeColor: root.selected
        ? Theme.active
        : (root.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.58) : Qt.rgba(1, 1, 1, 0.14))
      strokeWidth: root.selected ? 3 : (root.hovered ? 2 : 1)
      startX: root.skewOffset
      startY: 0

      PathLine { x: root.width; y: 0 }
      PathLine { x: root.width - root.skewOffset; y: root.height }
      PathLine { x: 0; y: root.height }
      PathLine { x: root.skewOffset; y: 0 }
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
