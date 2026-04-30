import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import QtQuick.Shapes
import QtMultimedia
import "../"

// Slice behavior adapted from liixini/skwd-wall's MIT-licensed SliceDelegate.
Item {
  id: root

  required property var itemData
  property bool selected: false
  property bool hovered: false
  property int skewOffset: 22
  property int expandedWidth: 344
  property int hoverWidth: 214
  property int sliceWidth: 104
  property bool appeared: false
  signal activated()

  width: root.selected ? root.expandedWidth : (root.hovered ? root.hoverWidth : root.sliceWidth)
  height: 278
  z: root.selected ? 3 : (root.hovered ? 2 : 1)
  clip: false
  opacity: root.appeared ? 1 : 0
  scale: root.appeared ? 1 : 0.985

  readonly property bool expanded: root.selected || root.hovered
  readonly property real mediaScale: root.selected ? 1.0 : (root.hovered ? 1.05 : 1.18)
  readonly property bool isVideo: root.itemData.type === "video"
  readonly property string previewPath: root.itemData.thumb || root.itemData.path || ""
  readonly property string previewSource: mediaSource(previewPath)
  readonly property string videoSource: root.selected && root.isVideo ? mediaSource(root.itemData.path || "") : ""

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

  Behavior on opacity {
    NumberAnimation {
      duration: Theme.animDuration + 100
      easing.type: Easing.OutCubic
    }
  }

  Behavior on scale {
    NumberAnimation {
      duration: Theme.animDuration + 100
      easing.type: Easing.OutCubic
    }
  }

  transform: Translate {
    x: root.appeared ? 0 : 28

    Behavior on x {
      NumberAnimation {
        duration: Theme.animDuration + 100
        easing.type: Easing.OutCubic
      }
    }
  }

  Component.onCompleted: root.appeared = true

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
      visible: !root.isVideo || !root.selected

      Behavior on scale {
        NumberAnimation {
          duration: Theme.animDuration + 90
          easing.type: Easing.OutCubic
        }
      }
    }

    MediaPlayer {
      id: player
      source: root.videoSource
      videoOutput: videoOutput
      audioOutput: mutedOutput
      loops: MediaPlayer.Infinite
      autoPlay: root.selected && root.isVideo
    }

    AudioOutput {
      id: mutedOutput
      muted: true
    }

    VideoOutput {
      id: videoOutput
      anchors.fill: parent
      fillMode: VideoOutput.PreserveAspectCrop
      scale: root.mediaScale
      transformOrigin: Item.Center
      visible: root.itemData.type === "video" && root.selected

      Behavior on scale {
        NumberAnimation {
          duration: Theme.animDuration + 90
          easing.type: Easing.OutCubic
        }
      }
    }

    Rectangle {
      anchors.fill: parent
      color: Qt.rgba(0, 0, 0, 0.18)
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
        : (root.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.58) : Qt.rgba(1, 1, 1, 0.18))
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
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.rightMargin: root.skewOffset + 10
    anchors.bottomMargin: 10
    width: typeText.implicitWidth + 16
    height: 20
    radius: 4
    color: Qt.rgba(0, 0, 0, 0.62)

    Text {
      id: typeText
      anchors.centerIn: parent
      text: root.itemData.type === "video" ? "VID" : (root.itemData.source === "wallhaven" ? "WEB" : "IMG")
      color: Theme.active
      font.pixelSize: 10
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
