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
  readonly property int menuWidth: 454
  readonly property int menuHeight: 244
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardWidth: ShellState.topBarCWidth + 2 * root.fw
  readonly property int initialCardHeight: Theme.notchHeight

  property bool windowVisible: false
  property bool legacyRecording: false
  property real openProgress: Popups.toolboxOpen ? 1 : 0

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

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  ListModel {
    id: toolActions

    ListElement { label: "Screenshot";       hint: "Capture"; icon: "󰹑"; action: "screenshot";   accent: "#91d7e3" }
    ListElement { label: "Open Screenshots"; hint: "Folder";  icon: "󰉋"; action: "screenshots";  accent: "#8aadf4" }
    ListElement { label: "Screen Recorder";  hint: "Record";  icon: "󰻂"; action: "screenrecord"; accent: "#ed8796" }
    ListElement { label: "Open Recordings";  hint: "Folder";  icon: "󰉋"; action: "recordings";   accent: "#f5a97f" }
    ListElement { label: "Color Picker";     hint: "Pick";    icon: "󰈋"; action: "colorpicker";  accent: "#c6a0f6" }
    ListElement { label: "OCR";              hint: "Text";    icon: "󰷊"; action: "ocr";          accent: "#8bd5ca" }
    ListElement { label: "QR Code";          hint: "Scan";    icon: "󰐲"; action: "qr";           accent: "#eed49f" }
    ListElement { label: "Google Lens";      hint: "Search";  icon: "󰊭"; action: "google-lens";  accent: "#8aadf4" }
    ListElement { label: "Mirror";           hint: "Camera";  icon: "󰄀"; action: "mirror";       accent: "#f5bde6" }
    ListElement { label: "Caffeine";         hint: "Off";     icon: "󰅶"; action: "caffeine";     accent: "#a6da95" }
  }

  Connections {
    target: Popups

    function onToolboxOpenChanged() {
      if (Popups.toolboxOpen) {
        closeTimer.stop()
        root.windowVisible = true
        root.refreshLegacyRecording()
      } else {
        closeTimer.restart()
      }
    }
  }

  Timer {
    id: closeTimer
    interval: Theme.motionExpandDuration + 50
    onTriggered: root.windowVisible = false
  }

  Process {
    id: actionRunner
    command: []
    running: false
    onRunningChanged: if (!running) command = []
  }

  Timer {
    id: actionDelay
    interval: Theme.motionExpandDuration + 80
    repeat: false
    property var command: []
    onTriggered: {
      actionRunner.running = false
      actionRunner.command = command
      actionRunner.running = true
      command = []
    }
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

  function runProcess(command) {
    Popups.closeAll()
    actionDelay.command = command
    actionDelay.restart()
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
        Popups.closeAll()
        return
      }

      if (ShellState.screenRecord) {
        ScreenRecService.cancelSetup()
      } else {
        ShellState.screenRecord = true
      }

      Popups.closeAll()
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
      Popups.closeAll()
      Popups.mirrorScreenName = screen ? screen.name : ""
      Popups.mirrorOpen = true
      return
    case "caffeine":
      CaffeineService.toggle()
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
      color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.96)
      strokeColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.24)
      strokeWidth: 1
      radius: Theme.cornerRadius
      flareWidth: root.fw
      flareHeight: root.fh
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    Item {
      anchors {
        fill: parent
        topMargin: Theme.notchHeight + 8
        leftMargin: root.fw + 10
        rightMargin: root.fw + 10
        bottomMargin: 10
      }

      opacity: Math.min(1, root.openProgress * 1.35)

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration }
      }

      Grid {
        id: grid
        width: parent.width
        columns: 2
        rowSpacing: 6
        columnSpacing: 6

        readonly property int buttonWidth: (width - columnSpacing) / 2
        readonly property int buttonHeight: 38

        Repeater {
          model: toolActions

          delegate: Rectangle {
            id: button

            required property string label
            required property string hint
            required property string icon
            required property string action
            required property color accent

            readonly property bool recordingAction: button.action === "screenrecord"
            readonly property bool caffeineAction: button.action === "caffeine"
            readonly property bool recorderActiveAction: button.recordingAction && (ScreenRecService.recording || root.legacyRecording)
            readonly property bool recorderSetupAction: button.recordingAction && ShellState.screenRecord && !ScreenRecService.recording && !root.legacyRecording
            readonly property bool activeAction: button.recorderActiveAction || button.recorderSetupAction
                                         || button.caffeineAction && CaffeineService.active

            width: grid.buttonWidth
            height: grid.buttonHeight
            radius: 7
            color: button.activeAction ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.18)
                  : hover.hovered ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.12)
                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.04)
            border.color: button.activeAction ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.46)
                        : hover.hovered ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.32)
                        : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.10)
            border.width: 1

            Behavior on color { ColorAnimation { duration: 120 } }
            Behavior on border.color { ColorAnimation { duration: 120 } }

            Rectangle {
              id: iconBadge
              anchors {
                left: parent.left
                leftMargin: 8
                verticalCenter: parent.verticalCenter
              }
              width: 24
              height: 24
              radius: 7
              color: Qt.rgba(button.accent.r, button.accent.g, button.accent.b, button.activeAction ? 0.26 : 0.14)

              Text {
                anchors.centerIn: parent
                text: button.recorderActiveAction ? "⏹"
                    : button.recorderSetupAction ? "✕"
                    : button.icon
                color: button.accent
                font.pixelSize: 13
              }
            }

            Column {
              anchors {
                left: iconBadge.right
                leftMargin: 8
                right: parent.right
                rightMargin: 8
                verticalCenter: parent.verticalCenter
              }
              spacing: -1

              Text {
                width: parent.width
                text: button.recorderActiveAction ? "Stop Recording"
                    : button.recorderSetupAction ? "Cancel Setup"
                    : button.label
                color: Theme.text
                font.pixelSize: 10
                font.weight: Font.Medium
                elide: Text.ElideRight
              }

              Text {
                width: parent.width
                text: button.recorderActiveAction ? "Active"
                    : button.recorderSetupAction ? "Setup"
                    : button.caffeineAction && CaffeineService.active ? "On"
                    : button.hint
                color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.44)
                font.pixelSize: 8
                elide: Text.ElideRight
              }
            }

            HoverHandler {
              id: hover
              cursorShape: Qt.PointingHandCursor
            }

            MouseArea {
              anchors.fill: parent
              onClicked: root.runAction(button.action)
            }
          }
        }
      }
    }
  }

  Item {
    anchors.fill: parent
    focus: root.visible
    Keys.onEscapePressed: Popups.closeAll()
  }
}
