import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../shapes"

PanelWindow {
  id: root

  Binding { target: Popups; property: "systemMenuVisible"; value: card.visible }

  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius
  readonly property int menuWidth: 288
  readonly property int menuHeight: 322
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardWidth: Math.max(Theme.lNotchMinWidth, ShellState.topBarLWidth) + 2 * root.fw
  readonly property int initialCardHeight: Theme.notchHeight

  readonly property var sessionActions: [
    {
      label: "Screensaver",
      hint: "Start now",
      icon: "󰍹",
      command: ["ryoku-launch-screensaver", "force"]
    },
    {
      label: "Lock",
      hint: "Secure session",
      icon: "󰌾",
      command: ["ryoku-lock-screen"]
    },
    {
      label: "Suspend",
      hint: "Sleep",
      icon: "⏾",
      command: ["systemctl", "suspend"]
    },
    {
      label: "Hibernate",
      hint: "Save to disk",
      icon: "󰒲",
      command: ["systemctl", "hibernate"]
    }
  ]

  readonly property var powerActions: [
    {
      label: "Log Out",
      hint: "End session",
      icon: "󰍃",
      danger: true,
      confirm: true,
      title: "Log Out?",
      message: "You will be logged out of your session. Save your work before continuing.",
      confirmLabel: "Log Out",
      action: "logout"
    },
    {
      label: "Restart",
      hint: "Reboot system",
      icon: "↺",
      danger: true,
      confirm: true,
      title: "Restart?",
      message: "Your computer will restart. Save your work before continuing.",
      confirmLabel: "Restart",
      action: "reboot"
    },
    {
      label: "Shutdown",
      hint: "Power off",
      icon: "⏻",
      danger: true,
      confirm: true,
      title: "Shut Down?",
      message: "Your computer will power off. Save your work before continuing.",
      confirmLabel: "Shut Down",
      action: "shutdown"
    }
  ]

  property bool windowVisible: false
  property real openProgress: Popups.systemMenuOpen ? 1 : 0

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.systemMenuOpen ? Easing.OutBack : Easing.OutQuart
      easing.overshoot: 1.08
    }
  }

  color: "transparent"
  visible: root.windowVisible
  exclusionMode: ExclusionMode.Ignore

  anchors {
    top: true
    left: true
    right: true
    bottom: true
  }

  WlrLayershell.layer: WlrLayer.Top
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Connections {
    target: Popups

    function onSystemMenuOpenChanged() {
      if (Popups.systemMenuOpen) {
        closeTimer.stop()
        root.windowVisible = true
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

  function runAction(action) {
    if (!action) return

    if (action.confirm) {
      Popups.closeAll()
      Popups.showConfirm(action.title, action.message, action.confirmLabel, action.action)
      return
    }

    actionRunner.command = action.command
    actionRunner.running = true
    Popups.closeAll()
  }

  MouseArea {
    anchors.fill: parent
    enabled: root.windowVisible
    onClicked: Popups.closeAll()
  }

  Item {
    id: card

    anchors.left: parent.left
    anchors.top: parent.top

    width: root.initialCardWidth + (root.fullCardWidth - root.initialCardWidth) * root.openProgress
    height: root.initialCardHeight + (root.fullCardHeight - root.initialCardHeight) * root.openProgress
    visible: root.openProgress > 0
    clip: true

    PopupShape {
      anchors.fill: parent
      attachedEdge: "top"
      color: Theme.background
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
        topMargin: Theme.notchHeight + 9
        leftMargin: root.fw + 10
        rightMargin: root.fw + 10
        bottomMargin: 12
      }

      opacity: Math.min(1, root.openProgress * 1.4)

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration }
      }

      Column {
        id: content
        anchors.fill: parent
        spacing: 7

        Text {
          width: parent.width
          text: "Session"
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.58)
          font.pixelSize: 11
          font.bold: true
        }

        Repeater {
          model: root.sessionActions

          MenuButton {
            width: content.width
            label: modelData && modelData.label ? modelData.label : ""
            hint: modelData && modelData.hint ? modelData.hint : ""
            icon: modelData && modelData.icon ? modelData.icon : ""
            danger: false
            onClicked: root.runAction(modelData)
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
        }

        Text {
          width: parent.width
          text: "Power"
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.58)
          font.pixelSize: 11
          font.bold: true
        }

        Repeater {
          model: root.powerActions

          MenuButton {
            width: content.width
            label: modelData && modelData.label ? modelData.label : ""
            hint: modelData && modelData.hint ? modelData.hint : ""
            icon: modelData && modelData.icon ? modelData.icon : ""
            danger: !!(modelData && modelData.danger)
            onClicked: root.runAction(modelData)
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

  component MenuButton: Rectangle {
    id: button

    required property string label
    required property string icon
    property string hint: ""
    property bool danger: false

    signal clicked()

    height: 32
    radius: 7
    color: hover.hovered
           ? (button.danger ? Qt.rgba(0.45, 0.12, 0.12, 0.55) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18))
           : "transparent"
    scale: hover.hovered ? 1.015 : 1

    Behavior on color { ColorAnimation { duration: 130 } }
    Behavior on scale {
      enabled: !Theme.staticMode
      NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
    }

    Row {
      anchors {
        fill: parent
        leftMargin: 9
        rightMargin: 9
      }
      spacing: 9

      Text {
        width: 20
        anchors.verticalCenter: parent.verticalCenter
        text: button.icon
        color: button.danger && hover.hovered ? "#ff7777" : Theme.text
        font.pixelSize: 14
        horizontalAlignment: Text.AlignHCenter
      }

      Column {
        width: parent.width - 29
        anchors.verticalCenter: parent.verticalCenter
        spacing: 0

        Text {
          width: parent.width
          text: button.label
          color: Theme.text
          font.pixelSize: 12
          elide: Text.ElideRight
        }

        Text {
          width: parent.width
          text: button.hint
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
          font.pixelSize: 10
          elide: Text.ElideRight
        }
      }
    }

    HoverHandler {
      id: hover
      cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
      anchors.fill: parent
      onClicked: button.clicked()
    }
  }
}
