import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Wayland
import "../"

PanelWindow {
  id: root

  readonly property bool primaryInstance: Popups.mirrorScreenName !== ""
                                          && screen
                                          && screen.name === Popups.mirrorScreenName

  readonly property int panelWidth: Math.min(520, Math.max(0, root.width - 48))
  readonly property int panelHeight: Math.min(390, Math.max(180, root.height - 80))
  readonly property bool hasCamera: mediaDevices.videoInputs.length > 0
  readonly property bool cameraProblem: !root.hasCamera || camera.errorString !== ""

  function closeMirror() {
    Popups.mirrorOpen = false
    Popups.mirrorScreenName = ""
  }

  color: "transparent"
  visible: root.primaryInstance && Popups.mirrorOpen
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  MediaDevices {
    id: mediaDevices
  }

  Camera {
    id: camera
    cameraDevice: mediaDevices.defaultVideoInput
    active: root.visible && root.hasCamera
  }

  CaptureSession {
    camera: camera
    videoOutput: preview
  }

  Rectangle {
    anchors.fill: parent
    color: "#99000000"

    MouseArea {
      anchors.fill: parent
      enabled: root.visible
      onClicked: root.closeMirror()
    }
  }

  Rectangle {
    id: panel

    anchors.centerIn: parent
    width: root.panelWidth
    height: root.panelHeight
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.96)
    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.24)
    border.width: 1
    clip: true

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    Column {
      anchors {
        fill: parent
        margins: 12
      }
      spacing: 10

      Item {
        id: header

        width: parent.width
        height: 30

        Text {
          anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
          }
          text: "Mirror"
          color: Theme.text
          font.pixelSize: 13
          font.weight: Font.Medium
        }

        Rectangle {
          id: closeButton

          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          width: 28
          height: 28
          radius: 7
          color: closeHover.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
                                    : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
          border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
          border.width: 1

          Behavior on color { ColorAnimation { duration: 120 } }

          Text {
            anchors.centerIn: parent
            text: "X"
            color: Theme.text
            font.pixelSize: 12
            font.weight: Font.DemiBold
          }

          HoverHandler {
            id: closeHover
            cursorShape: Qt.PointingHandCursor
          }

          MouseArea {
            anchors.fill: parent
            onClicked: root.closeMirror()
          }
        }
      }

      Rectangle {
        id: previewFrame

        width: parent.width
        height: Math.max(96, parent.height - header.height - parent.spacing)
        radius: 8
        color: "#000000"
        clip: true

        VideoOutput {
          id: preview

          anchors.fill: parent
          fillMode: VideoOutput.PreserveAspectCrop
          transform: Scale {
            origin.x: preview.width / 2
            origin.y: preview.height / 2
            xScale: -1
          }
        }

        Rectangle {
          anchors.fill: parent
          visible: root.cameraProblem
          color: "#000000"

          Text {
            anchors.centerIn: parent
            width: parent.width - 32
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.hasCamera ? ("Camera unavailable\n" + camera.errorString) : "No camera found"
            color: Theme.text
            font.pixelSize: 12
          }
        }
      }
    }
  }

  Item {
    anchors.fill: parent
    focus: root.visible
    Keys.onEscapePressed: root.closeMirror()
  }
}
