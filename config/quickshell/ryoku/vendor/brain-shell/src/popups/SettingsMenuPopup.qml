import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"
import "../shapes"

PanelWindow {
  id: root

  Binding { target: Popups; property: "settingsMenuVisible"; value: card.visible }

  readonly property int fw: Theme.notchRadius
  readonly property int fh: Theme.notchRadius
  readonly property int menuWidth: 282
  readonly property int menuHeight: 162
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardHeight: Theme.notchHeight

  property bool windowVisible: false
  property real openProgress: Popups.settingsMenuOpen ? 1 : 0

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.settingsMenuOpen ? Easing.OutBack : Easing.OutQuart
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
    id: settingsActions

    ListElement { label: "Audio";      hint: "Sound";    icon: "󰕾"; action: "audio";     accent: "#eed49f" }
    ListElement { label: "Wi-Fi";      hint: "Network";  icon: "󰤨"; action: "wifi";      accent: "#7dc4e4" }
    ListElement { label: "Bluetooth";  hint: "Devices";  icon: "󰂯"; action: "bluetooth"; accent: "#8aadf4" }
    ListElement { label: "Activity";   hint: "btop";     icon: "󰍛"; action: "activity";  accent: "#a6da95" }
    ListElement { label: "Dotfiles";   hint: "Config hub"; icon: "󰒓"; action: "dotfiles"; accent: "#f5bde6" }
  }

  Connections {
    target: Popups

    function onSettingsMenuOpenChanged() {
      if (Popups.settingsMenuOpen) {
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
    case "dotfiles":
      Popups.closeAll()
      Popups.dotfilesOpen = true
      return
    case "audio":
      actionRunner.command = ["ryoku-launch-audio"]
      break
    case "wifi":
      actionRunner.command = ["ryoku-launch-wifi"]
      break
    case "bluetooth":
      actionRunner.command = ["ryoku-launch-bluetooth"]
      break
    case "activity":
      actionRunner.command = ["ryoku-launch-tui", "btop"]
      break
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

    anchors.right: parent.right
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
      radius: 8
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
        leftMargin: root.fw + 9
        rightMargin: root.fw + 9
        bottomMargin: 8
      }

      opacity: Math.min(1, root.openProgress * 1.35)

      Behavior on opacity {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration }
      }

      Column {
        anchors.fill: parent
        spacing: 7

        Item {
          width: parent.width
          height: 24

          Rectangle {
            id: headerRule
            width: 3
            height: 18
            radius: 2
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.active
          }

          Column {
            anchors {
              left: headerRule.right
              leftMargin: 9
              verticalCenter: parent.verticalCenter
            }
            spacing: -1

            Text {
              text: "Ryoku"
              color: Theme.text
              font.pixelSize: 12
              font.bold: true
            }

            Text {
              text: "Control center"
              color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
              font.pixelSize: 9
            }
          }

          Text {
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            text: "settings"
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
            font.pixelSize: 9
          }
        }

        Grid {
          id: grid
          width: parent.width
          columns: 2
          rowSpacing: 5
          columnSpacing: 6

          Repeater {
            model: settingsActions

            delegate: Rectangle {
              id: tile

              required property string label
              required property string hint
              required property string icon
              required property color accent
              required property string action

              width: (grid.width - grid.columnSpacing) / 2
              height: 32
              radius: 6
              color: hover.hovered ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.14)
                                   : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.034)
              border.width: 1
              border.color: hover.hovered ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.38)
                                          : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

              Behavior on color { ColorAnimation { duration: 130 } }
              Behavior on border.color { ColorAnimation { duration: 130 } }

              Rectangle {
                width: 3
                radius: 2
                anchors {
                  top: parent.top
                  bottom: parent.bottom
                  left: parent.left
                  topMargin: 8
                  bottomMargin: 8
                }
                color: tile.accent
                opacity: hover.hovered ? 0.95 : 0.55
              }

              Row {
                anchors {
                  fill: parent
                  leftMargin: 11
                  rightMargin: 8
                }
                spacing: 0

                Column {
                  width: parent.width
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: -1

                  Text {
                    width: parent.width
                    text: tile.label
                    color: Theme.text
                    font.pixelSize: 10
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: tile.hint
                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
                    font.pixelSize: 8
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
                onClicked: root.runAction(tile.action)
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
