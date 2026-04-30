import QtQuick
import Quickshell.Io
import "../../"
import "../../services/"

Item {
  id: root

  required property var screen

  readonly property int buttonSize: 26
  readonly property int iconSize: 13
  readonly property int buttonSpacing: 8
  readonly property int separatorWidth: 1
  readonly property color selectionAccentColor: "#F25623"
  readonly property color idleIconColor: "#ffffff"
  readonly property color selectedFill: Qt.rgba(selectionAccentColor.r, selectionAccentColor.g, selectionAccentColor.b, 0.16)
  readonly property color selectedIconColor: idleIconColor
  readonly property color activeFill: Qt.rgba(selectionAccentColor.r, selectionAccentColor.g, selectionAccentColor.b, 0.24)
  readonly property color activeIconColor: idleIconColor
  readonly property color separatorColor: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.16)

  property bool legacyRecording: false
  property bool trailActive: false
  property int currentIndex: 0
  property string hoveredTooltip: ""
  property bool tooltipVisible: false

  implicitWidth: toolsRow.implicitWidth
  implicitHeight: root.buttonSize
  width: implicitWidth
  height: root.buttonSize
  visible: true
  enabled: Popups.toolboxOpen
  focus: Popups.toolboxOpen
  opacity: Popups.toolboxOpen ? 1 : 0

  Behavior on opacity {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.toolboxOpen ? Easing.OutCubic : Easing.OutQuart
    }
  }

  onCurrentIndexChanged: {
    trailActive = true
    trailFadeTimer.restart()
  }

  ListModel {
    id: toolActions

    ListElement { separator: false; tooltip: "Screenshot";       icon: "\ue10e"; action: "screenshot" }
    ListElement { separator: false; tooltip: "Screen Recorder";  icon: "\ue4da"; action: "screenrecord" }
    ListElement { separator: true;  tooltip: "";                 icon: "";       action: "" }
    ListElement { separator: false; tooltip: "Color Picker";     icon: "\ue568"; action: "colorpicker" }
    ListElement { separator: false; tooltip: "OCR";              icon: "\ue48a"; action: "ocr" }
    ListElement { separator: false; tooltip: "QR Code";          icon: "\ue3e6"; action: "qr" }
    ListElement { separator: false; tooltip: "Google Lens";      icon: "\ue292"; action: "google-lens" }
    ListElement { separator: true;  tooltip: "";                 icon: "";       action: "" }
    ListElement { separator: false; tooltip: "Mirror";           icon: "\ue9b2"; action: "mirror" }
    ListElement { separator: false; tooltip: "Caffeine";         icon: "\ue1c2"; action: "caffeine" }
    ListElement { separator: true;  tooltip: "";                 icon: "";       action: "" }
    ListElement { separator: false; tooltip: "Open Screenshots"; icon: "\ue2cc"; action: "screenshots" }
    ListElement { separator: false; tooltip: "Open Recordings";  icon: "\ue792"; action: "recordings" }
  }

  Connections {
    target: Popups

    function onToolboxOpenChanged() {
      if (Popups.toolboxOpen) {
        actionStartTimer.stop()
        actionStartTimer.command = []
        actionStartTimer.action = ""
        root.tooltipVisible = false
        root.hoveredTooltip = ""
        root.currentIndex = 0
        root.refreshLegacyRecording()
        Qt.callLater(function() { root.forceActiveFocus() })
      } else {
        root.tooltipVisible = false
        root.hoveredTooltip = ""
        submapReset.running = false
        submapReset.running = true
      }
    }

    function onToolboxActionRequested(action) {
      if (!Popups.toolboxOpen && action !== "close") return

      switch (action) {
      case "previous":
        root.moveSelection(-1)
        return
      case "next":
        root.moveSelection(1)
        return
      case "activate":
        root.activateCurrent()
        return
      case "close":
        root.closeToolbox()
        return
      default:
        return
      }
    }
  }

  Timer {
    id: actionStartTimer
    interval: Theme.motionExpandDuration + 120
    repeat: false
    property var command: []
    property string action: ""
    onTriggered: {
      if (command.length > 0) {
        actionRunner.running = false
        actionRunner.command = command
        actionRunner.running = true
      } else if (action !== "") {
        root.performDelayedAction(action)
      }

      command = []
      action = ""
    }
  }

  Timer {
    id: tooltipTimer
    interval: 500
    repeat: false
    onTriggered: root.tooltipVisible = root.hoveredTooltip !== ""
  }

  Timer {
    id: trailFadeTimer
    interval: 220
    repeat: false
    onTriggered: root.trailActive = false
  }

  Process {
    id: actionRunner
    command: []
    running: false
    onRunningChanged: if (!running) command = []
  }

  Process {
    id: submapReset
    command: ["hyprctl", "dispatch", "submap", "reset"]
    running: false
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
    running: root.visible
    repeat: true
    onTriggered: root.refreshLegacyRecording()
  }

  function closeToolbox() {
    tooltipTimer.stop()
    root.tooltipVisible = false
    root.hoveredTooltip = ""
    Popups.toolboxOpen = false
  }

  function refreshLegacyRecording() {
    if (legacyRecorderCheck.running) return

    legacyRecorderCheck.running = true
  }

  function runProcess(command) {
    closeToolbox()
    actionStartTimer.action = ""
    actionStartTimer.command = []
    actionRunner.running = false
    actionRunner.command = ["bash", "-c", "sleep 0.45; exec \"$@\"", "ryoku-toolbox-action"].concat(command)
    actionRunner.running = true
  }

  function runDelayedAction(action) {
    closeToolbox()
    actionStartTimer.command = []
    actionStartTimer.action = action
    actionStartTimer.restart()
  }

  function screenRecordTooltip() {
    if (ScreenRecService.recording || root.legacyRecording) return "Stop Recording"
    if (Popups.screenRecordToolOpen) return "Cancel Recorder"
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
    if (action === "screenrecord" && Popups.screenRecordToolOpen) return "\ue4f6"
    if (action === "mirror" && Popups.mirrorOpen) return "\uecdc"
    return icon
  }

  function isActionActive(action) {
    if (action === "screenrecord") {
      return ScreenRecService.recording || root.legacyRecording || Popups.screenRecordToolOpen
    }
    if (action === "mirror") return Popups.mirrorOpen
    if (action === "caffeine") return CaffeineService.active
    return false
  }

  function selectIndex(index) {
    if (index < 0 || index >= toolActions.count) return

    var item = toolActions.get(index)
    if (item.separator) return

    currentIndex = index
    hoveredTooltip = actionTooltip(item.action, item.tooltip)
    tooltipVisible = false
    tooltipTimer.restart()
  }

  function moveSelection(delta) {
    if (toolActions.count === 0) return

    var index = currentIndex
    for (var i = 0; i < toolActions.count; i++) {
      index = (index + delta + toolActions.count) % toolActions.count
      if (!toolActions.get(index).separator) {
        selectIndex(index)
        return
      }
    }
  }

  function activateCurrent() {
    if (currentIndex < 0 || currentIndex >= toolActions.count) return

    var item = toolActions.get(currentIndex)
    if (!item.separator)
      runAction(item.action)
  }

  function selectedButtonX() {
    var item = toolRepeater.itemAt(currentIndex)
    return item ? item.x : 0
  }

  Keys.onPressed: function(event) {
    if (!Popups.toolboxOpen) return

    switch (event.key) {
    case Qt.Key_Left:
    case Qt.Key_Up:
      moveSelection(-1)
      event.accepted = true
      return
    case Qt.Key_Right:
    case Qt.Key_Down:
      moveSelection(1)
      event.accepted = true
      return
    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
      activateCurrent()
      event.accepted = true
      return
    case Qt.Key_Escape:
      closeToolbox()
      event.accepted = true
      return
    default:
      return
    }
  }

  function performDelayedAction(action) {
    switch (action) {
    case "screenshot-start":
      ScreenshotService.startCapture("normal")
      Popups.screenshotToolOpen = true
      return
    case "qr-start":
      ScreenshotService.startCapture("qr")
      Popups.screenshotToolOpen = true
      return
    case "lens-start":
      ScreenshotService.startCapture("lens")
      Popups.screenshotToolOpen = true
      return
    case "screenrecord-start":
      ScreenRecService.initialize()
      Popups.screenRecordToolOpen = true
      return
    case "screenrecord-cancel":
      Popups.screenRecordToolOpen = false
      return
    case "mirror":
      Popups.mirrorScreenName = screen ? screen.name : ""
      Popups.mirrorOpen = true
      return
    default:
      return
    }
  }

  function runAction(action) {
    switch (action) {
    case "screenshot":
      runDelayedAction("screenshot-start")
      return
    case "screenshots":
      runProcess(["bash", "-c", "[[ -f ~/.config/user-dirs.dirs ]] && source ~/.config/user-dirs.dirs; dir=\"${RYOKU_SCREENSHOT_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}\"; mkdir -p \"$dir\"; xdg-open \"$dir\""])
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
        closeToolbox()
        return
      }

      runDelayedAction(Popups.screenRecordToolOpen ? "screenrecord-cancel" : "screenrecord-start")
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
      runDelayedAction("qr-start")
      return
    case "google-lens":
      runDelayedAction("lens-start")
      return
    case "mirror":
      runDelayedAction("mirror")
      return
    case "caffeine":
      CaffeineService.toggle()
      closeToolbox()
      return
    default:
      return
    }
  }

  Row {
    id: toolsRow

    anchors.centerIn: parent
    spacing: root.buttonSpacing
    z: 1

    Repeater {
      id: toolRepeater
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
          color: toolItem.active
               ? root.activeFill
               : !toolItem.selected && clickArea.containsMouse
                 ? Qt.rgba(root.selectionAccentColor.r, root.selectionAccentColor.g, root.selectionAccentColor.b, 0.1)
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
          color: toolItem.active ? root.activeIconColor
               : toolItem.selected ? root.selectedIconColor
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
            root.selectIndex(index)
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

  Item {
    id: selectionLayer

    anchors.centerIn: parent
    width: toolsRow.implicitWidth
    height: root.buttonSize
    visible: Popups.toolboxOpen
    z: 0

    Rectangle {
      id: cursorTrailFar

      x: root.selectedButtonX()
      width: root.buttonSize
      height: root.buttonSize
      radius: width / 2
      color: Qt.rgba(root.selectionAccentColor.r, root.selectionAccentColor.g, root.selectionAccentColor.b, 0.08)
      opacity: root.trailActive ? 1 : 0

      Behavior on x {
        enabled: !Theme.staticMode
        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
      }

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: 170; easing.type: Easing.OutCubic }
      }
    }

    Rectangle {
      id: cursorTrailNear

      x: root.selectedButtonX()
      width: root.buttonSize
      height: root.buttonSize
      radius: width / 2
      color: Qt.rgba(root.selectionAccentColor.r, root.selectionAccentColor.g, root.selectionAccentColor.b, 0.14)
      opacity: root.trailActive ? 1 : 0

      Behavior on x {
        enabled: !Theme.staticMode
        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
      }

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
      }
    }

    Rectangle {
      id: selectionCursor

      x: root.selectedButtonX()
      width: root.buttonSize
      height: root.buttonSize
      radius: width / 2
      color: root.selectedFill

      Behavior on x {
        enabled: !Theme.staticMode
        NumberAnimation { duration: 115; easing.type: Easing.OutCubic }
      }
    }
  }
}
