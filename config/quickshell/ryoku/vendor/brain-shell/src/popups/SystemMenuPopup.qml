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
  readonly property int menuWidth: 306
  readonly property int menuHeight: 226
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardHeight: Theme.notchHeight

  property bool windowVisible: false
  property real openProgress: Popups.systemMenuOpen ? 1 : 0

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.systemMenuOpen ? Easing.OutBack : Easing.OutQuart
      easing.overshoot: 1.06
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

  ListModel {
    id: systemActions

    ListElement { label: "Screensaver"; hint: "Start now"; icon: "󰍹"; action: "screensaver"; accent: "#91d7e3"; danger: false }
    ListElement { label: "Lock";        hint: "Secure";    icon: "󰌾"; action: "lock";        accent: "#8aadf4"; danger: false }
    ListElement { label: "Suspend";     hint: "Sleep";     icon: "⏾"; action: "suspend";     accent: "#a6da95"; danger: false }
    ListElement { label: "Hibernate";   hint: "Disk";      icon: "󰒲"; action: "hibernate";   accent: "#eed49f"; danger: false }
    ListElement { label: "Log Out";     hint: "Session";   icon: "󰍃"; action: "logout";      accent: "#f5a97f"; danger: true }
    ListElement { label: "Restart";     hint: "Reboot";    icon: "↺"; action: "reboot";      accent: "#f5a97f"; danger: true }
    ListElement { label: "Shutdown";    hint: "Power off"; icon: "⏻"; action: "shutdown";    accent: "#ed8796"; danger: true }
  }

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
    switch (action) {
    case "screensaver":
      actionRunner.command = ["ryoku-launch-screensaver", "force"]
      break
    case "lock":
      actionRunner.command = ["ryoku-lock-screen"]
      break
    case "suspend":
      actionRunner.command = ["systemctl", "suspend"]
      break
    case "hibernate":
      actionRunner.command = ["systemctl", "hibernate"]
      break
    case "logout":
      Popups.closeAll()
      Popups.showConfirm(
        "Log Out?",
        "You will be logged out of your session. Save your work before continuing.",
        "Log Out",
        "logout"
      )
      return
    case "reboot":
      Popups.closeAll()
      Popups.showConfirm(
        "Restart?",
        "Your computer will restart. Save your work before continuing.",
        "Restart",
        "reboot"
      )
      return
    case "shutdown":
      Popups.closeAll()
      Popups.showConfirm(
        "Shut Down?",
        "Your computer will power off. Save your work before continuing.",
        "Shut Down",
        "shutdown"
      )
      return
    default:
      return
    }

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

    width: root.fullCardWidth
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

      Column {
        anchors.fill: parent
        spacing: 8

        Item {
          width: parent.width
          height: 28

          Rectangle {
            id: headerMark
            width: 24
            height: 24
            radius: 8
            anchors.verticalCenter: parent.verticalCenter
            color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)

            Text {
              anchors.centerIn: parent
              text: "⏻"
              color: Theme.active
              font.pixelSize: 13
              font.bold: true
            }
          }

          Column {
            anchors {
              left: headerMark.right
              leftMargin: 8
              verticalCenter: parent.verticalCenter
            }
            spacing: -1

            Text {
              text: "System"
              color: Theme.text
              font.pixelSize: 13
              font.bold: true
            }

            Text {
              text: "Session controls"
              color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
              font.pixelSize: 9
            }
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            text: "power"
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
            font.pixelSize: 10
          }
        }

        Grid {
          id: grid
          width: parent.width
          columns: 2
          rowSpacing: 6
          columnSpacing: 6

          Repeater {
            model: systemActions

            delegate: Rectangle {
              id: button

              required property string label
              required property string hint
              required property string icon
              required property color accent
              required property bool danger
              required property string action

              width: (grid.width - grid.columnSpacing) / 2
              height: 38
              radius: 8
              color: hover.hovered ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, button.danger ? 0.24 : 0.18)
                                   : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
              border.width: 1
              border.color: hover.hovered ? Qt.rgba(button.accent.r, button.accent.g, button.accent.b, 0.48)
                                          : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
              scale: hover.hovered ? 1.025 : 1

              Behavior on color { ColorAnimation { duration: 130 } }
              Behavior on border.color { ColorAnimation { duration: 130 } }
              Behavior on scale {
                enabled: !Theme.staticMode
                NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
              }

              Row {
                anchors {
                  fill: parent
                  leftMargin: 7
                  rightMargin: 8
                }
                spacing: 7

                Rectangle {
                  id: iconBadge
                  width: 26
                  height: 26
                  radius: 8
                  anchors.verticalCenter: parent.verticalCenter
                  color: Qt.rgba(button.accent.r, button.accent.g, button.accent.b, hover.hovered ? 0.30 : 0.16)

                  Text {
                    anchors.centerIn: parent
                    text: button.icon
                    color: button.danger && hover.hovered ? "#ff9a9a" : Theme.text
                    font.pixelSize: 13
                  }
                }

                Column {
                  width: parent.width - iconBadge.width - parent.spacing
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: -1

                  Text {
                    width: parent.width
                    text: button.label
                    color: button.danger && hover.hovered ? "#ff9a9a" : Theme.text
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: button.hint
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
                    font.pixelSize: 9
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
                onClicked: root.runAction(button.action)
              }
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
