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
  readonly property int menuWidth: 316
  readonly property int menuHeight: 262
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardHeight: Theme.notchHeight
  readonly property string homeDir: Quickshell.env("HOME")

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

    ListElement { label: "Apps";       hint: "Launcher"; icon: "󰀻"; action: "apps";      accent: "#8bd5ca" }
    ListElement { label: "Wallpapers"; hint: "Desktop";  icon: "󰸉"; action: "wallpaper"; accent: "#91d7e3" }
    ListElement { label: "Themes";     hint: "System";   icon: "󰔎"; action: "theme";     accent: "#c6a0f6" }
    ListElement { label: "Audio";      hint: "Sound";    icon: "󰕾"; action: "audio";     accent: "#eed49f" }
    ListElement { label: "Wi-Fi";      hint: "Network";  icon: "󰤨"; action: "wifi";      accent: "#7dc4e4" }
    ListElement { label: "Bluetooth";  hint: "Devices";  icon: "󰂯"; action: "bluetooth"; accent: "#8aadf4" }
    ListElement { label: "Activity";   hint: "btop";     icon: "󰍛"; action: "activity";  accent: "#a6da95" }
    ListElement { label: "Config";     hint: "Hyprland"; icon: "󰒓"; action: "config";    accent: "#f5bde6" }
    ListElement { label: "Update";     hint: "System";   icon: "󰚰"; action: "update";    accent: "#f5a97f" }
    ListElement { label: "Power";      hint: "Session";  icon: "⏻"; action: "system";    accent: "#ed8796" }
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
    case "wallpaper":
      Popups.closeAll()
      Popups.wallpaperMode = "wallpaper"
      Popups.wallpaperOpen = true
      return
    case "theme":
      Popups.closeAll()
      Popups.wallpaperMode = "theme"
      Popups.wallpaperOpen = true
      return
    case "system":
      Popups.closeAll()
      Popups.systemMenuOpen = true
      return
    case "apps":
      actionRunner.command = ["ryoku-launch-drun"]
      break
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
    case "config":
      actionRunner.command = ["ryoku-launch-editor", root.homeDir + "/.config/hypr/hyprland.conf"]
      break
    case "update":
      actionRunner.command = ["ryoku-launch-floating-terminal-with-presentation", "ryoku-update"]
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
              text: "力"
              color: Theme.active
              font.family: "Noto Sans CJK JP"
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
              text: "Ryoku"
              color: Theme.text
              font.pixelSize: 13
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
            model: settingsActions

            delegate: Rectangle {
              id: tile

              required property string label
              required property string hint
              required property string icon
              required property color accent
              required property string action

              width: (grid.width - grid.columnSpacing) / 2
              height: 38
              radius: 8
              color: hover.hovered ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.18)
                                   : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
              border.width: 1
              border.color: hover.hovered ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.46)
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
                  color: Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, hover.hovered ? 0.28 : 0.16)

                  Text {
                    anchors.centerIn: parent
                    text: tile.icon
                    color: Theme.text
                    font.pixelSize: 13
                  }
                }

                Column {
                  width: parent.width - iconBadge.width - parent.spacing
                  anchors.verticalCenter: parent.verticalCenter
                  spacing: -1

                  Text {
                    width: parent.width
                    text: tile.label
                    color: Theme.text
                    font.pixelSize: 11
                    font.bold: true
                    elide: Text.ElideRight
                  }

                  Text {
                    width: parent.width
                    text: tile.hint
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
