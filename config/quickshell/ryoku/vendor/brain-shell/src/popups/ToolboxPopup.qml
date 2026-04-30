import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../services/"
import "../shapes"

PanelWindow {
  id: root

  Binding { target: Popups; property: "toolboxVisible"; value: card.visible }

  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius
  readonly property int buttonSize: 26
  readonly property int iconSize: 13
  readonly property int buttonSpacing: 8
  readonly property int separatorWidth: 1
  readonly property int buttonCount: 10
  readonly property int separatorCount: 2
  readonly property int menuWidth: buttonCount * buttonSize + separatorCount * separatorWidth
                                   + (buttonCount + separatorCount - 1) * buttonSpacing + 16
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight
  readonly property int initialCardWidth: ShellState.topBarCWidth + 2 * root.fw
  readonly property int initialCardHeight: Theme.notchHeight
  readonly property color idleIconColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.58)
  readonly property color selectedFill: Theme.text
  readonly property color selectedIconColor: Theme.background
  readonly property color separatorColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)

  property bool windowVisible: false
  property bool legacyRecording: false
  property int currentIndex: 0
  property string hoveredTooltip: ""
  property bool tooltipVisible: false
  property real openProgress: Popups.toolboxOpen ? 1 : 0
  readonly property real toolsOpacity: Popups.toolboxOpen
                                       ? Math.min(1, root.openProgress * 1.8)
                                       : root.openProgress

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.toolboxOpen ? Easing.OutBack : Easing.OutQuart
      easing.overshoot: 1.10
    }
  }

  color: "transparent"
  visible: root.windowVisible
  implicitHeight: root.fullCardHeight + 8
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  ListModel {
    id: toolActions

    ListElement { separator: false; tooltip: "Screenshot";       icon: "\ue10e"; action: "screenshot" }
    ListElement { separator: false; tooltip: "Open Screenshots"; icon: "\ue2cc"; action: "screenshots" }
    ListElement { separator: true;  tooltip: "";                 icon: "";       action: "" }
    ListElement { separator: false; tooltip: "Screen Recorder";  icon: "\ue4da"; action: "screenrecord" }
    ListElement { separator: false; tooltip: "Open Recordings";  icon: "\ue792"; action: "recordings" }
    ListElement { separator: true;  tooltip: "";                 icon: "";       action: "" }
    ListElement { separator: false; tooltip: "Color Picker";     icon: "\ue568"; action: "colorpicker" }
    ListElement { separator: false; tooltip: "OCR";              icon: "\ue48a"; action: "ocr" }
    ListElement { separator: false; tooltip: "QR Code";          icon: "\ue3e6"; action: "qr" }
    ListElement { separator: false; tooltip: "Google Lens";      icon: "\ue292"; action: "google-lens" }
    ListElement { separator: false; tooltip: "Mirror";           icon: "\ue9b2"; action: "mirror" }
    ListElement { separator: false; tooltip: "Caffeine";         icon: "\ue1c2"; action: "caffeine" }
  }

  Connections {
    target: Popups

    function onToolboxOpenChanged() {
      if (Popups.toolboxOpen) {
        closeTimer.stop()
        actionStartTimer.stop()
        actionStartTimer.command = []
        root.windowVisible = true
        root.tooltipVisible = false
        root.hoveredTooltip = ""
        root.currentIndex = 0
        root.refreshLegacyRecording()
      } else {
        closeTimer.restart()
      }
    }
  }

  Timer {
    id: closeTimer
    interval: Theme.motionExpandDuration + Theme.motionEffectsDuration + 120
    onTriggered: root.windowVisible = false
  }

  Timer {
    id: actionStartTimer
    interval: Theme.motionExpandDuration + 40
    repeat: false
    property var command: []
    onTriggered: {
      actionRunner.running = false
      actionRunner.command = command
      actionRunner.running = true
      command = []
    }
  }

  Timer {
    id: tooltipTimer
    interval: 500
    repeat: false
    onTriggered: root.tooltipVisible = root.hoveredTooltip !== ""
  }

  Process {
    id: actionRunner
    command: []
    running: false
    onRunningChanged: if (!running) command = []
  }

  Process {
    id: legacyRecorderStop
    command: ["ryoku-cmd-screenrecord", "--stop-recording"]
    running: false
    onExited: root.refreshLegacyRecording()
  }

  Process {
    id: legacyRecorderCheck
    command: ["pgrep", "-f", "^gpu-screen-recorder"]
    running: false
    onExited: function(exitCode, exitStatus) {
      root.legacyRecording = exitCode === 0
    }
  }

  Timer {
    interval: 1800
    running: root.windowVisible
    repeat: true
    onTriggered: root.refreshLegacyRecording()
  }

  function refreshLegacyRecording() {
    if (legacyRecorderCheck.running) return

    legacyRecorderCheck.running = true
  }

  function closeToolboxNow() {
    tooltipTimer.stop()
    root.tooltipVisible = false
    root.hoveredTooltip = ""
    Popups.closeAll()
    if (root.windowVisible) closeTimer.restart()
  }

  function runProcess(command) {
    closeToolboxNow()
    actionStartTimer.command = command
    actionStartTimer.restart()
  }

  function screenRecordTooltip() {
    if (ScreenRecService.recording || root.legacyRecording) return "Stop Recording"
    if (ShellState.screenRecord) return "Cancel Setup"
    return "Screen Recorder"
  }

  function actionTooltip(action, tooltip) {
    if (action === "screenrecord") return screenRecordTooltip()
    if (action === "mirror" && Popups.mirrorOpen) return "Close Mirror"
    if (action === "caffeine" && CaffeineService.active) return "Caffeine On"
    return tooltip
  }

  function actionIcon(action, icon) {
    if (action === "screenrecord" && (ScreenRecService.recording || root.legacyRecording)) return "\ue46c"
    if (action === "screenrecord" && ShellState.screenRecord) return "\ue4f6"
    if (action === "mirror" && Popups.mirrorOpen) return "\uecdc"
    return icon
  }

  function isActionActive(action) {
    if (action === "screenrecord") {
      return ScreenRecService.recording || root.legacyRecording || ShellState.screenRecord
    }
    if (action === "mirror") return Popups.mirrorOpen
    if (action === "caffeine") return CaffeineService.active
    return false
  }

  function runAction(action) {
    switch (action) {
    case "screenshot":
      runProcess(["ryoku-cmd-screenshot"])
      return
    case "screenshots":
      runProcess(["bash", "-c", "[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs; dir=\"${RYOKU_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}}\"; mkdir -p \"$dir\"; xdg-open \"$dir\""])
      return
    case "screenrecord":
      var recordingActive = ScreenRecService.recording || root.legacyRecording
      if (ScreenRecService.recording) {
        ScreenRecService.stopRecording()
      }
      if (root.legacyRecording) {
        legacyRecorderStop.running = false
        legacyRecorderStop.running = true
      }
      if (recordingActive) {
        closeToolboxNow()
        return
      }

      if (ShellState.screenRecord) {
        ScreenRecService.cancelSetup()
      } else {
        ShellState.screenRecord = true
      }

      closeToolboxNow()
      return
    case "recordings":
      runProcess(["bash", "-c", "[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs; dir=\"${RYOKU_SCREENRECORD_DIR:-${XDG_VIDEOS_DIR:-$HOME/Videos}/screen_recordings}\"; mkdir -p \"$dir\"; xdg-open \"$dir\""])
      return
    case "colorpicker":
      runProcess(["ryoku-cmd-colorpicker"])
      return
    case "ocr":
      runProcess(["ryoku-cmd-ocr"])
      return
    case "qr":
      runProcess(["ryoku-cmd-qr-scan"])
      return
    case "google-lens":
      runProcess(["ryoku-cmd-google-lens"])
      return
    case "mirror":
      closeToolboxNow()
      Popups.mirrorScreenName = screen ? screen.name : ""
      Popups.mirrorOpen = true
      return
    case "caffeine":
      CaffeineService.toggle()
      closeToolboxNow()
      return
    default:
      return
    }
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.windowVisible
    onClicked: Popups.closeAll()
  }

  Item {
    id: card

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top

    width: root.initialCardWidth + (root.fullCardWidth - root.initialCardWidth) * root.openProgress
    height: root.initialCardHeight + (root.fullCardHeight - root.initialCardHeight) * root.openProgress
    visible: root.openProgress > 0
    clip: true

    PopupShape {
      anchors.fill: parent
      attachedEdge: "top"
      color: Theme.background
      strokeColor: "transparent"
      strokeWidth: 0
      radius: Theme.cornerRadius
      flareWidth: root.fw
      flareHeight: root.fh
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    Row {
      id: toolsRow

      anchors.centerIn: parent
      spacing: root.buttonSpacing
      opacity: root.toolsOpacity

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration }
      }

      Repeater {
        model: toolActions

        delegate: Item {
          id: toolItem

          required property bool separator
          required property string tooltip
          required property string icon
          required property string action
          required property int index

          readonly property bool selected: !separator && index === root.currentIndex
          readonly property bool active: !separator && root.isActionActive(action)

          width: separator ? root.separatorWidth : root.buttonSize
          height: root.buttonSize

          Rectangle {
            visible: toolItem.separator
            anchors.centerIn: parent
            width: root.separatorWidth
            height: 12
            radius: 1
            color: root.separatorColor
          }

          Rectangle {
            visible: !toolItem.separator
            anchors.fill: parent
            radius: width / 2
            color: toolItem.selected
                 ? root.selectedFill
                 : clickArea.containsMouse
                   ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                   : "transparent"

            Behavior on color {
              enabled: !Theme.staticMode
              ColorAnimation { duration: 110 }
            }
          }

          Text {
            visible: !toolItem.separator
            anchors.centerIn: parent
            text: root.actionIcon(toolItem.action, toolItem.icon)
            font.family: "Phosphor"
            font.pixelSize: root.iconSize
            font.weight: Font.Bold
            color: toolItem.selected ? root.selectedIconColor
                 : toolItem.active ? Theme.active
                 : root.idleIconColor
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter

            Behavior on color {
              enabled: !Theme.staticMode
              ColorAnimation { duration: 110 }
            }
          }

          MouseArea {
            id: clickArea

            anchors.fill: parent
            enabled: !toolItem.separator
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor

            onEntered: {
              root.currentIndex = index
              root.hoveredTooltip = root.actionTooltip(toolItem.action, toolItem.tooltip)
              root.tooltipVisible = false
              tooltipTimer.restart()
            }

            onExited: {
              tooltipTimer.stop()
              root.tooltipVisible = false
              root.hoveredTooltip = ""
            }

            onClicked: root.runAction(toolItem.action)
          }
        }
      }
    }

    Rectangle {
      id: tooltipBubble

      anchors {
        horizontalCenter: toolsRow.horizontalCenter
        top: toolsRow.bottom
        topMargin: 7
      }

      width: tooltipText.implicitWidth + 16
      height: 24
      radius: 6
      visible: root.tooltipVisible
      opacity: root.tooltipVisible ? 1 : 0
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98)
      border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)
      border.width: 1

      Text {
        id: tooltipText

        anchors.centerIn: parent
        text: root.hoveredTooltip
        color: Theme.text
        font.pixelSize: 10
        font.weight: Font.Medium
      }
    }
  }

  Item {
    anchors.fill: parent
    focus: root.visible
    Keys.onEscapePressed: Popups.closeAll()
  }
}
