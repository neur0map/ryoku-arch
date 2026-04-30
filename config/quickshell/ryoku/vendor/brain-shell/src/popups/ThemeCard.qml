import QtQuick
import "../"

Item {
  id: root

  required property var itemData
  property bool selected: false
  property bool hovered: false
  signal activated()

  width: expanded ? 178 : 112
  height: 236
  scale: root.hovered && !root.selected ? 1.025 : 1.0
  z: root.selected ? 3 : (root.hovered ? 2 : 1)

  readonly property bool expanded: root.selected || root.hovered
  readonly property string previewSource: mediaSource(root.itemData.preview || "")
  readonly property string label: root.itemData.display || root.itemData.name || ""

  function mediaSource(path) {
    if (!path || path === "") return ""
    if (path.indexOf("file://") === 0) return path
    return "file://" + path
  }

  Behavior on width {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Behavior on scale {
    NumberAnimation {
      duration: Theme.animDuration
      easing.type: Easing.OutCubic
    }
  }

  Rectangle {
    id: shell
    anchors.fill: parent
    radius: 8
    color: Qt.rgba(1, 1, 1, 0.08)
    border.width: root.selected ? 3 : (root.hovered ? 2 : 1)
    border.color: root.selected
      ? Theme.active
      : (root.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.58) : Qt.rgba(1, 1, 1, 0.16))
    clip: true

    Image {
      anchors.fill: parent
      source: root.previewSource
      fillMode: Image.PreserveAspectCrop
      asynchronous: true
      visible: root.previewSource !== ""
    }

    Rectangle {
      anchors.fill: parent
      color: root.previewSource === ""
        ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16)
        : Qt.rgba(0, 0, 0, 0.12)
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      height: 46
      color: Qt.rgba(0, 0, 0, 0.62)

      Text {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: 10
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
      anchors.rightMargin: 8
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
  }

  HoverHandler {
    cursorShape: Qt.PointingHandCursor
    onHoveredChanged: root.hovered = hovered
  }

  TapHandler {
    onTapped: root.activated()
  }
}
