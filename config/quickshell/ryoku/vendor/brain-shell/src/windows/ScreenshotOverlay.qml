import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../services/"

PanelWindow {
  id: root

  property string imagePath: ""

  color: "transparent"
  visible: imagePath !== ""
  exclusionMode: ExclusionMode.Ignore

  anchors {
    left: true
    bottom: true
  }

  implicitWidth: overlayRow.implicitWidth + 24
  implicitHeight: overlayRow.implicitHeight + 24

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  Connections {
    target: ScreenshotService

    function onImageSaved(path) {
      if (root.screen && ScreenshotService.lastMonitorName !== "" && root.screen.name !== ScreenshotService.lastMonitorName)
        return

      root.imagePath = path
      hideTimer.restart()
    }
  }

  Process {
    id: copyProcess
    command: []
    running: false
  }

  Process {
    id: deleteProcess
    command: []
    running: false
  }

  Process {
    id: editProcess
    command: []
    running: false
  }

  Timer {
    id: hideTimer
    interval: 5000
    repeat: false
    onTriggered: if (!hoverArea.containsMouse) root.imagePath = ""
  }

  MouseArea {
    id: hoverArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.NoButton
  }

  Row {
    id: overlayRow
    anchors {
      left: parent.left
      bottom: parent.bottom
      margins: 16
    }
    spacing: 8

    Rectangle {
      width: 220
      height: 132
      radius: 8
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.94)
      border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45)
      border.width: 1
      clip: true

      Image {
        anchors.fill: parent
        anchors.margins: 4
        source: root.imagePath === "" ? "" : "file://" + root.imagePath
        fillMode: Image.PreserveAspectCrop
        cache: false
      }

      MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Qt.openUrlExternally("file://" + root.imagePath)
      }
    }

    Column {
      anchors.verticalCenter: parent.verticalCenter
      spacing: 6

      OverlayButton {
        icon: "󰆏"
        tooltip: "Copy"
        onTriggered: {
          copyProcess.command = ["bash", "-c", "wl-copy --type image/png < " + ScreenshotService._shellQuote(root.imagePath)]
          copyProcess.running = false
          copyProcess.running = true
          hideTimer.restart()
        }
      }

      OverlayButton {
        icon: "󰆓"
        tooltip: "Close"
        onTriggered: root.imagePath = ""
      }

      OverlayButton {
        icon: "󰏫"
        tooltip: "Edit with Gradia"
        onTriggered: {
          editProcess.command = ["ryoku-cmd-image-edit", root.imagePath]
          editProcess.running = false
          editProcess.running = true
          root.imagePath = ""
        }
      }

      OverlayButton {
        icon: "󰆴"
        tooltip: "Delete"
        destructive: true
        onTriggered: {
          deleteProcess.command = ["rm", "-f", root.imagePath]
          deleteProcess.running = false
          deleteProcess.running = true
          root.imagePath = ""
        }
      }
    }
  }

  component OverlayButton: Rectangle {
    id: button

    required property string icon
    property string tooltip: ""
    property bool destructive: false
    signal triggered

    width: 34
    height: 34
    radius: 8
    color: clickArea.containsMouse
      ? (destructive ? Qt.rgba(0.9, 0.16, 0.16, 0.28) : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.14))
      : Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.94)
    border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)
    border.width: 1

    Text {
      anchors.centerIn: parent
      text: button.icon
      color: button.destructive ? "#ff6b6b" : Theme.text
      font.pixelSize: 15
    }

    MouseArea {
      id: clickArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: button.triggered()
    }
  }
}
