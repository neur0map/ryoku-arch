import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../services/"

PanelWindow {
  id: root

  property string localState: "idle"
  property real dragStartX: 0
  property real dragStartY: 0

  color: "transparent"
  visible: Popups.screenshotToolOpen
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    bottom: true
    left: true
    right: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: root.visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  onVisibleChanged: {
    if (visible) {
      localState = ScreenshotService.freezing ? "loading" : "active"
    } else {
      localState = "idle"
      previewImage.source = ""
    }
  }

  function closeTool() {
    ScreenshotService.cancelCapture()
    Popups.screenshotToolOpen = false
  }

  function executeCapture() {
    if (ScreenshotService.currentMode === "screen") {
      ScreenshotService.processMonitorScreen(root.screen.name)
      Popups.screenshotToolOpen = false
      return
    }

    if (ScreenshotService.currentMode === "region" && ScreenshotService.selectionW > 5 && ScreenshotService.selectionH > 5) {
      ScreenshotService.processRegion(
        ScreenshotService.selectionX,
        ScreenshotService.selectionY,
        ScreenshotService.selectionW,
        ScreenshotService.selectionH
      )
      Popups.screenshotToolOpen = false
    }
  }

  Connections {
    target: ScreenshotService

    function onCaptureReady() {
      if (root.visible)
        root.localState = "active"
    }

    function onMonitorScreenshotReady(monitorName, path) {
      if (!root.screen || monitorName !== root.screen.name) return

      previewImage.source = ""
      previewImage.source = "file://" + path
      root.localState = "active"
    }

    function onErrorOccurred(message) {
      console.warn("ScreenshotTool:", message)
      root.closeTool()
    }
  }

  mask: Region {
    item: root.visible ? fullMask : emptyMask
  }

  Item {
    id: fullMask
    anchors.fill: parent
  }

  Item {
    id: emptyMask
    width: 0
    height: 0
  }

  FocusScope {
    anchors.fill: parent
    focus: root.visible

    Keys.onEscapePressed: root.closeTool()

    Rectangle {
      anchors.fill: parent
      color: "#000000"
      opacity: root.localState === "loading" ? 0.45 : 0
      visible: opacity > 0
    }

    Image {
      id: previewImage
      anchors.fill: parent
      cache: false
      fillMode: Image.Stretch
      visible: root.localState === "active" && source !== ""
    }

    Rectangle {
      anchors.fill: parent
      color: "#000000"
      opacity: root.localState === "active" && ScreenshotService.currentMode !== "screen" ? 0.38 : 0
      visible: opacity > 0
    }

    Item {
      anchors.fill: parent
      visible: root.localState === "active" && ScreenshotService.currentMode === "window"

      Repeater {
        model: ScreenshotService.windows

        delegate: Rectangle {
          x: modelData.at[0] - (root.screen ? root.screen.x : 0)
          y: modelData.at[1] - (root.screen ? root.screen.y : 0)
          width: modelData.size[0]
          height: modelData.size[1]
          color: hoverHandler.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2) : "transparent"
          border.color: hoverHandler.hovered ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.2)
          border.width: 2

          HoverHandler {
            id: hoverHandler
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              ScreenshotService.processRegion(modelData.at[0], modelData.at[1], modelData.size[0], modelData.size[1])
              Popups.screenshotToolOpen = false
            }
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.localState === "active" && (ScreenshotService.currentMode === "region" || ScreenshotService.currentMode === "screen")
      hoverEnabled: true
      cursorShape: ScreenshotService.currentMode === "region" ? Qt.CrossCursor : Qt.ArrowCursor

      onPressed: function(mouse) {
        if (ScreenshotService.currentMode === "screen") return

        root.dragStartX = mouse.x + (root.screen ? root.screen.x : 0)
        root.dragStartY = mouse.y + (root.screen ? root.screen.y : 0)
        ScreenshotService.selectionX = root.dragStartX
        ScreenshotService.selectionY = root.dragStartY
        ScreenshotService.selectionW = 0
        ScreenshotService.selectionH = 0
      }

      onClicked: {
        if (ScreenshotService.currentMode === "screen")
          root.executeCapture()
      }

      onPositionChanged: function(mouse) {
        if (ScreenshotService.currentMode !== "region" || !(mouse.buttons & Qt.LeftButton)) return

        var currentX = mouse.x + (root.screen ? root.screen.x : 0)
        var currentY = mouse.y + (root.screen ? root.screen.y : 0)
        ScreenshotService.selectionX = Math.min(root.dragStartX, currentX)
        ScreenshotService.selectionY = Math.min(root.dragStartY, currentY)
        ScreenshotService.selectionW = Math.abs(root.dragStartX - currentX)
        ScreenshotService.selectionH = Math.abs(root.dragStartY - currentY)
      }

      onReleased: {
        if (ScreenshotService.currentMode === "region")
          root.executeCapture()
      }
    }

    Rectangle {
      visible: root.localState === "active" && ScreenshotService.currentMode === "region"
      x: ScreenshotService.selectionX - (root.screen ? root.screen.x : 0)
      y: ScreenshotService.selectionY - (root.screen ? root.screen.y : 0)
      width: ScreenshotService.selectionW
      height: ScreenshotService.selectionH
      color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
      border.color: Theme.active
      border.width: 2
    }

    Rectangle {
      anchors {
        bottom: parent.bottom
        horizontalCenter: parent.horizontalCenter
        bottomMargin: 48
      }
      width: controlsRow.implicitWidth + 20
      height: 48
      radius: 24
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.94)
      border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)
      border.width: 1
      visible: root.localState === "active"

      Row {
        id: controlsRow
        anchors.centerIn: parent
        spacing: 8

        ModeButton {
          mode: "region"
          icon: "󰩭"
          label: "Region"
        }

        ModeButton {
          mode: "window"
          icon: "󱂬"
          label: "Window"
        }

        ModeButton {
          mode: "screen"
          icon: "󰍹"
          label: "Screen"
        }
      }
    }
  }

  component ModeButton: Rectangle {
    id: button

    required property string mode
    required property string icon
    required property string label

    width: 88
    height: 32
    radius: 16
    color: ScreenshotService.currentMode === mode ? Theme.text
         : clickArea.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
         : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

    Row {
      anchors.centerIn: parent
      spacing: 6

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: button.icon
        color: ScreenshotService.currentMode === button.mode ? Theme.background : Theme.text
        font.pixelSize: 13
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: button.label
        color: ScreenshotService.currentMode === button.mode ? Theme.background : Theme.text
        font.pixelSize: 12
        font.weight: Font.Medium
      }
    }

    MouseArea {
      id: clickArea
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: ScreenshotService.currentMode = button.mode
    }
  }
}
