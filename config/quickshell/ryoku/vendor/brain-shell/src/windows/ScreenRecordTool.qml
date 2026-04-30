import QtQuick
import Quickshell
import Quickshell.Wayland
import "../"
import "../services/"

PanelWindow {
  id: root

  property string currentMode: "region"
  property bool recordAudioOutput: false
  property bool recordAudioInput: false
  property real dragStartX: 0
  property real dragStartY: 0
  property real selectionX: 0
  property real selectionY: 0
  property real selectionW: 0
  property real selectionH: 0
  property string pendingRecordMode: ""
  property string pendingRecordGeometry: ""
  property bool pendingRecordAudioOutput: false
  property bool pendingRecordAudioInput: false
  property string pendingRecordMonitorName: ""

  color: "transparent"
  visible: Popups.screenRecordToolOpen
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
    if (!visible) return

    ScreenRecService.initialize()
    ScreenshotService.fetchWindows()
    currentMode = ScreenRecService.canRecordDirectly ? "region" : "portal"
    recordAudioOutput = false
    recordAudioInput = false
    selectionW = 0
    selectionH = 0
  }

  function closeTool() {
    Popups.screenRecordToolOpen = false
  }

  Timer {
    id: startRecordTimer
    interval: 120
    repeat: false
    onTriggered: {
      ScreenRecService.startRecording(
        root.pendingRecordMode,
        root.pendingRecordGeometry,
        root.pendingRecordAudioOutput,
        root.pendingRecordAudioInput,
        root.pendingRecordMonitorName
      )
    }
  }

  function queueRecording(mode, geometry, audioOutput, audioInput, monitorName) {
    pendingRecordMode = mode
    pendingRecordGeometry = geometry
    pendingRecordAudioOutput = audioOutput
    pendingRecordAudioInput = audioInput
    pendingRecordMonitorName = monitorName
    closeTool()
    startRecordTimer.restart()
  }

  function screenOffsetX() {
    return root.screen && root.screen.x !== undefined ? root.screen.x : 0
  }

  function screenOffsetY() {
    return root.screen && root.screen.y !== undefined ? root.screen.y : 0
  }

  function startSelectedRecording() {
    if (!ScreenRecService.canRecordDirectly && currentMode !== "portal")
      currentMode = "portal"

    if (currentMode === "portal") {
      queueRecording("portal", "", recordAudioOutput, recordAudioInput, "")
      return
    }

    if (currentMode === "screen") {
      queueRecording("screen", "", recordAudioOutput, recordAudioInput, root.screen ? root.screen.name : "")
      return
    }

    if (currentMode === "region" && selectionW > 5 && selectionH > 5) {
      var regionStr = Math.round(selectionW) + "x" + Math.round(selectionH) + "+" +
                      Math.round(selectionX + screenOffsetX()) + "+" + Math.round(selectionY + screenOffsetY())
      queueRecording("region", regionStr, recordAudioOutput, recordAudioInput, "")
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
      opacity: 0.42
    }

    Text {
      anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: controlsBar.top
        bottomMargin: 14
      }
      visible: !ScreenRecService.canRecordDirectly
      text: "ScreenRecorder unavailable"
      color: "#ffb4b4"
      font.pixelSize: 12
      font.weight: Font.Medium
    }

    Item {
      anchors.fill: parent
      visible: root.currentMode === "window" && ScreenRecService.canRecordDirectly

      Repeater {
        model: ScreenshotService.windows

        delegate: Rectangle {
          x: modelData.at[0] - root.screenOffsetX()
          y: modelData.at[1] - root.screenOffsetY()
          width: modelData.size[0]
          height: modelData.size[1]
          color: hoverHandler.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.2) : "transparent"
          border.color: hoverHandler.hovered ? Theme.active : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.22)
          border.width: 2

          HoverHandler {
            id: hoverHandler
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              var regionStr = Math.round(modelData.size[0]) + "x" + Math.round(modelData.size[1]) + "+" +
                              Math.round(modelData.at[0]) + "+" + Math.round(modelData.at[1])
              root.queueRecording("region", regionStr, root.recordAudioOutput, root.recordAudioInput, "")
            }
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.currentMode === "region" || root.currentMode === "screen" || root.currentMode === "portal"
      hoverEnabled: true
      cursorShape: root.currentMode === "region" && ScreenRecService.canRecordDirectly ? Qt.CrossCursor : Qt.ArrowCursor

      onPressed: function(mouse) {
        if (root.currentMode !== "region" || !ScreenRecService.canRecordDirectly) return

        root.dragStartX = mouse.x
        root.dragStartY = mouse.y
        root.selectionX = mouse.x
        root.selectionY = mouse.y
        root.selectionW = 0
        root.selectionH = 0
      }

      onClicked: {
        if (root.currentMode === "screen" || root.currentMode === "portal")
          root.startSelectedRecording()
      }

      onPositionChanged: function(mouse) {
        if (root.currentMode !== "region" || !(mouse.buttons & Qt.LeftButton)) return

        root.selectionX = Math.min(root.dragStartX, mouse.x)
        root.selectionY = Math.min(root.dragStartY, mouse.y)
        root.selectionW = Math.abs(root.dragStartX - mouse.x)
        root.selectionH = Math.abs(root.dragStartY - mouse.y)
      }

      onReleased: {
        if (root.currentMode === "region")
          root.startSelectedRecording()
      }
    }

    Rectangle {
      visible: root.currentMode === "region" && ScreenRecService.canRecordDirectly
      x: root.selectionX
      y: root.selectionY
      width: root.selectionW
      height: root.selectionH
      color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
      border.color: Theme.active
      border.width: 2
    }

    Rectangle {
      id: controlsBar
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

      Row {
        id: controlsRow
        anchors.centerIn: parent
        spacing: 8

        ToggleButton {
          icon: root.recordAudioOutput ? "󰕾" : "󰖁"
          active: root.recordAudioOutput
          enabled: true
          onTriggered: root.recordAudioOutput = !root.recordAudioOutput
        }

        ToggleButton {
          icon: root.recordAudioInput ? "󰍬" : "󰍭"
          active: root.recordAudioInput
          enabled: true
          onTriggered: root.recordAudioInput = !root.recordAudioInput
        }

        Separator {}

        ModeButton {
          mode: "region"
          icon: "󰩭"
          enabled: ScreenRecService.canRecordDirectly
        }

        ModeButton {
          mode: "window"
          icon: "󱂬"
          enabled: ScreenRecService.canRecordDirectly
        }

        ModeButton {
          mode: "screen"
          icon: "󰍹"
          enabled: ScreenRecService.canRecordDirectly
        }

        ModeButton {
          mode: "portal"
          icon: "󰹑"
          enabled: true
        }
      }
    }
  }

  component Separator: Rectangle {
    width: 1
    height: 18
    radius: 1
    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.18)
    anchors.verticalCenter: parent.verticalCenter
  }

  component ToggleButton: Rectangle {
    id: button

    required property string icon
    property bool active: false
    signal triggered

    width: 32
    height: 32
    radius: 16
    color: active ? Theme.text
         : clickArea.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
         : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
    opacity: enabled ? 1 : 0.42

    Text {
      anchors.centerIn: parent
      text: button.icon
      color: button.active ? Theme.background : Theme.text
      font.pixelSize: 14
    }

    MouseArea {
      id: clickArea
      anchors.fill: parent
      hoverEnabled: true
      enabled: button.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: button.triggered()
    }
  }

  component ModeButton: Rectangle {
    id: button

    required property string mode
    required property string icon

    width: 32
    height: 32
    radius: 16
    color: root.currentMode === mode ? Theme.text
         : clickArea.containsMouse ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.12)
         : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)
    opacity: enabled ? 1 : 0.38

    Text {
      anchors.centerIn: parent
      text: button.icon
      color: root.currentMode === button.mode ? Theme.background : Theme.text
      font.pixelSize: 14
    }

    MouseArea {
      id: clickArea
      anchors.fill: parent
      hoverEnabled: true
      enabled: button.enabled
      cursorShape: Qt.PointingHandCursor
      onClicked: root.currentMode = button.mode
    }
  }
}
