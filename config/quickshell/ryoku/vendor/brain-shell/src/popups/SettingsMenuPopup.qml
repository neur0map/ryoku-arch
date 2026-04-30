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
  readonly property int menuWidth: 350
  readonly property int menuHeight: 322
  readonly property int fullCardWidth: root.menuWidth + 2 * root.fw
  readonly property int fullCardHeight: Theme.notchHeight + root.menuHeight
  readonly property int initialCardWidth: Math.max(Theme.rNotchMinWidth, ShellState.topBarRWidth) + 2 * root.fw
  readonly property int initialCardHeight: Theme.notchHeight
  readonly property string homeDir: Quickshell.env("HOME")

  readonly property var actions: [
    {
      label: "Apps",
      icon: "󰀻",
      command: ["ryoku-launch-drun"]
    },
    {
      label: "Wallpapers",
      icon: "󰸉",
      popup: "wallpaper"
    },
    {
      label: "Themes",
      icon: "󰔎",
      popup: "theme"
    },
    {
      label: "Audio",
      icon: "󰕾",
      command: ["ryoku-launch-audio"]
    },
    {
      label: "Wi-Fi",
      icon: "󰤨",
      command: ["ryoku-launch-wifi"]
    },
    {
      label: "Bluetooth",
      icon: "󰂯",
      command: ["ryoku-launch-bluetooth"]
    },
    {
      label: "Activity",
      icon: "󰍛",
      command: ["ryoku-launch-tui", "btop"]
    },
    {
      label: "Keybinds",
      icon: "󰌌",
      command: ["ryoku-menu-keybindings"]
    },
    {
      label: "Update",
      icon: "󰚰",
      command: ["ryoku-launch-floating-terminal-with-presentation", "ryoku-update"]
    },
    {
      label: "Config",
      icon: "󰒓",
      command: ["ryoku-launch-editor", root.homeDir + "/.config/hypr/hyprland.conf"]
    },
    {
      label: "About",
      icon: "󰋼",
      command: ["ryoku-launch-about"]
    },
    {
      label: "System",
      icon: "⏻",
      popup: "system"
    }
  ]

  property bool windowVisible: false
  property real openProgress: Popups.settingsMenuOpen ? 1 : 0

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.settingsMenuOpen ? Easing.OutBack : Easing.OutQuart
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
    if (!action) return

    if (action.popup === "wallpaper") {
      Popups.closeAll()
      Popups.wallpaperMode = "wallpaper"
      Popups.wallpaperOpen = true
      return
    }

    if (action.popup === "theme") {
      Popups.closeAll()
      Popups.wallpaperMode = "theme"
      Popups.wallpaperOpen = true
      return
    }

    if (action.popup === "system") {
      Popups.closeAll()
      Popups.systemMenuOpen = true
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

    anchors.right: parent.right
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
        topMargin: Theme.notchHeight + 10
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
        anchors.fill: parent
        spacing: 9

        Item {
          width: parent.width
          height: 24

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Ryoku"
            color: Theme.text
            font.pixelSize: 13
            font.bold: true
          }

          Text {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: "settings"
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.42)
            font.pixelSize: 10
          }
        }

        Grid {
          id: grid
          width: parent.width
          columns: 2
          rowSpacing: 7
          columnSpacing: 7

          Repeater {
            model: root.actions

            MenuTile {
              width: (grid.width - grid.columnSpacing) / 2
              label: modelData && modelData.label ? modelData.label : ""
              icon: modelData && modelData.icon ? modelData.icon : ""
              onClicked: root.runAction(modelData)
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

  component MenuTile: Rectangle {
    id: tile

    required property string label
    required property string icon

    signal clicked()

    height: 39
    radius: 8
    color: hover.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                         : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
    border.width: 1
    border.color: hover.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.42)
                                : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
    scale: hover.hovered ? 1.035 : 1

    Behavior on color { ColorAnimation { duration: 130 } }
    Behavior on border.color { ColorAnimation { duration: 130 } }
    Behavior on scale {
      enabled: !Theme.staticMode
      NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
    }

    Row {
      anchors {
        fill: parent
        leftMargin: 10
        rightMargin: 10
      }
      spacing: 8

      Text {
        width: 18
        anchors.verticalCenter: parent.verticalCenter
        text: tile.icon
        color: Theme.text
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
      }

      Text {
        width: parent.width - 26
        anchors.verticalCenter: parent.verticalCenter
        text: tile.label
        color: Theme.text
        font.pixelSize: 12
        elide: Text.ElideRight
      }
    }

    HoverHandler {
      id: hover
      cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
      anchors.fill: parent
      onClicked: tile.clicked()
    }
  }
}
