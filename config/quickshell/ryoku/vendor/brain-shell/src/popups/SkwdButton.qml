import QtQuick
import "../"

// Adapted from liixini/skwd-wall's MIT-licensed FilterButton/ActionButton.
Item {
  id: root

  property string label: ""
  property bool active: false
  property bool interactive: true
  property int skew: 10
  property int horizontalPadding: 24
  property color accent: Theme.active
  property color textColor: root.active ? root.accent : Theme.text
  property real dimmedOpacity: root.interactive ? 1.0 : 0.74

  signal clicked()

  implicitWidth: Math.max(42, labelText.implicitWidth + root.horizontalPadding + root.skew)
  implicitHeight: 28
  width: implicitWidth
  height: implicitHeight
  opacity: root.dimmedOpacity
  scale: root.hovered && root.interactive ? 1.025 : 1.0

  readonly property bool hovered: hover.hovered

  Behavior on scale {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Canvas {
    id: canvas
    anchors.fill: parent

    property color fillColor: root.active
      ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, root.hovered ? 0.30 : 0.22)
      : (root.hovered && root.interactive
        ? Qt.rgba(1, 1, 1, 0.13)
        : Qt.rgba(1, 1, 1, 0.075))
    property color strokeColor: root.active
      ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.58)
      : (root.hovered && root.interactive
        ? Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.42)
        : Qt.rgba(1, 1, 1, 0.12))

    onFillColorChanged: requestPaint()
    onStrokeColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
      var ctx = getContext("2d")
      var sk = Math.min(root.skew, Math.max(0, width / 3))
      ctx.clearRect(0, 0, width, height)
      ctx.fillStyle = fillColor
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
    id: labelText
    anchors.centerIn: parent
    text: root.label
    color: root.textColor
    font.pixelSize: 11
    font.weight: root.active ? Font.DemiBold : Font.Medium
    elide: Text.ElideRight
    maximumLineCount: 1
  }

  HoverHandler {
    id: hover
    cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
  }

  TapHandler {
    enabled: root.interactive
    onTapped: root.clicked()
  }
}
