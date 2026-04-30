import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

PanelWindow {
  id: root

  Binding { target: Popups; property: "dotfilesVisible"; value: modal.visible }

  readonly property int modalWidth: 760
  readonly property int modalHeight: 560
  readonly property string homeDir: Quickshell.env("HOME")

  property bool windowVisible: false
  property real openProgress: Popups.dotfilesOpen ? 1 : 0

  Behavior on openProgress {
    enabled: !Theme.staticMode
    NumberAnimation {
      duration: Theme.motionExpandDuration
      easing.type: Popups.dotfilesOpen ? Easing.OutCubic : Easing.InCubic
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

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

  Connections {
    target: Popups

    function onDotfilesOpenChanged() {
      if (Popups.dotfilesOpen) {
        closeTimer.stop()
        root.windowVisible = true
        focusScope.forceActiveFocus()
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

  function absolutePath(path) {
    if (!path) return ""
    return path.charAt(0) === "/" ? path : root.homeDir + "/" + path
  }

  function openDotfile(path) {
    var target = root.absolutePath(path)
    if (target === "") return

    actionRunner.command = ["ryoku-launch-editor", target]
    actionRunner.running = true
    Popups.closeAll()
  }

  ListModel {
    id: hyprFiles

    ListElement { label: "Hyprland";   hint: "Main entry";   icon: ""; path: ".config/hypr/hyprland.conf"; accent: "#91d7e3" }
    ListElement { label: "Monitors";   hint: "Displays";     icon: "󰍹"; path: ".config/hypr/monitors.conf"; accent: "#7dc4e4" }
    ListElement { label: "Keybinds";   hint: "Shortcuts";    icon: "󰌌"; path: ".config/hypr/bindings.conf"; accent: "#8aadf4" }
    ListElement { label: "Input";      hint: "Keyboard";     icon: "󰌌"; path: ".config/hypr/input.conf"; accent: "#a6da95" }
    ListElement { label: "Look";       hint: "Gaps, blur";   icon: "󰉼"; path: ".config/hypr/looknfeel.conf"; accent: "#c6a0f6" }
    ListElement { label: "Autostart";  hint: "Startup";      icon: "󰐊"; path: ".config/hypr/autostart.conf"; accent: "#f5bde6" }
    ListElement { label: "Hypridle";   hint: "Idle";         icon: "󰒲"; path: ".config/hypr/hypridle.conf"; accent: "#eed49f" }
    ListElement { label: "Hyprlock";   hint: "Lock screen";  icon: "󰌾"; path: ".config/hypr/hyprlock.conf"; accent: "#ed8796" }
    ListElement { label: "Hyprsunset"; hint: "Night color";  icon: "󰔎"; path: ".config/hypr/hyprsunset.conf"; accent: "#f5a97f" }
  }

  ListModel {
    id: uiFiles

    ListElement { label: "Quickshell"; icon: "󱂬"; hint: "Shell config"; path: ".config/quickshell/ryoku/config/Config.qml"; accent: "#8bd5ca" }
    ListElement { label: "Shell Root"; icon: "󰘳"; hint: "QML entry";    path: ".config/quickshell/ryoku/shell.qml"; accent: "#91d7e3" }
    ListElement { label: "Mako";       icon: "󰍡"; hint: "Notifications"; path: ".config/mako/core.ini"; accent: "#f5bde6" }
    ListElement { label: "SwayOSD";    icon: "󰕾"; hint: "Controls";      path: ".config/swayosd/config.toml"; accent: "#eed49f" }
    ListElement { label: "Tofi";       icon: "󰀻"; hint: "Launcher";      path: ".config/tofi/config"; accent: "#a6da95" }
    ListElement { label: "UWSM";       icon: "󰒓"; hint: "Environment";   path: ".config/uwsm/default"; accent: "#8aadf4" }
  }

  ListModel {
    id: appFiles

    ListElement { label: "Ghostty";   icon: ""; hint: "Terminal"; path: ".config/ghostty/config"; accent: "#91d7e3" }
    ListElement { label: "Alacritty"; icon: ""; hint: "Terminal"; path: ".config/alacritty/alacritty.toml"; accent: "#8aadf4" }
    ListElement { label: "Kitty";     icon: ""; hint: "Terminal"; path: ".config/kitty/kitty.conf"; accent: "#c6a0f6" }
    ListElement { label: "Btop";      icon: "󰍛"; hint: "Activity"; path: ".config/btop/btop.conf"; accent: "#a6da95" }
    ListElement { label: "Fastfetch"; icon: "󰇅"; hint: "System info"; path: ".config/fastfetch/config.jsonc"; accent: "#f5a97f" }
    ListElement { label: "Git";       icon: "󰊢"; hint: "Git config"; path: ".config/git/config"; accent: "#ed8796" }
    ListElement { label: "Tmux";      icon: ""; hint: "Terminal mux"; path: ".config/tmux/tmux.conf"; accent: "#eed49f" }
  }

  ListModel {
    id: ryokuFiles

    ListElement { label: "Menu Hook";     icon: "󰈙"; hint: "Extensions"; path: ".config/ryoku/extensions/menu.sh"; accent: "#8bd5ca" }
    ListElement { label: "Post Update";   icon: "󰚰"; hint: "Hook";       path: ".config/ryoku/hooks/post-update"; accent: "#c6a0f6" }
    ListElement { label: "Theme Hook";    icon: "󰔎"; hint: "Hook";       path: ".config/ryoku/hooks/theme-set"; accent: "#f5bde6" }
    ListElement { label: "Theme Template"; icon: "󰈔"; hint: "Sample";    path: ".config/ryoku/themed/alacritty.toml.tpl.sample"; accent: "#91d7e3" }
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: root.openProgress * 0.46

    Behavior on opacity {
      enabled: !Theme.staticMode
      NumberAnimation { duration: Theme.motionEffectsDuration }
    }

    MouseArea {
      anchors.fill: parent
      enabled: root.windowVisible
      onClicked: Popups.closeAll()
    }
  }

  FocusScope {
    id: focusScope
    anchors.fill: parent
    focus: root.windowVisible

    Keys.onEscapePressed: Popups.closeAll()
  }

  Rectangle {
    id: modal

    width: Math.max(0, Math.min(root.modalWidth, parent.width - 48))
    height: Math.max(0, Math.min(root.modalHeight, parent.height - 96))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2 + (1 - root.openProgress) * 22
    visible: root.openProgress > 0
    opacity: root.openProgress
    scale: 0.96 + 0.04 * root.openProgress
    radius: Theme.cornerRadius
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.96)
    border.width: 1
    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.26)
    clip: true

    Behavior on y {
      enabled: !Theme.staticMode
      NumberAnimation { duration: Theme.motionExpandDuration; easing.type: Easing.OutCubic }
    }

    Behavior on opacity {
      enabled: !Theme.staticMode
      NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
    }

    Behavior on scale {
      enabled: !Theme.staticMode
      NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: mouse.accepted = true
    }

    Column {
      anchors {
        fill: parent
        margins: 18
      }
      spacing: 14

      Item {
        width: parent.width
        height: 34

        Rectangle {
          id: headerMark
          width: 30
          height: 30
          radius: 10
          anchors.verticalCenter: parent.verticalCenter
          color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)

          Text {
            anchors.centerIn: parent
            text: "󰒓"
            color: Theme.active
            font.pixelSize: 15
          }
        }

        Column {
          anchors {
            left: headerMark.right
            leftMargin: 10
            verticalCenter: parent.verticalCenter
          }
          spacing: -1

          Text {
            text: "Dotfiles"
            color: Theme.text
            font.pixelSize: 15
            font.bold: true
          }

          Text {
            text: "Configuration library"
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.44)
            font.pixelSize: 10
          }
        }

        Rectangle {
          width: 28
          height: 28
          radius: 9
          anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
          }
          color: closeHover.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                                    : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.06)

          Behavior on color { ColorAnimation { duration: 130 } }

          Text {
            anchors.centerIn: parent
            text: "×"
            color: Theme.text
            font.pixelSize: 14
            font.bold: true
          }

          HoverHandler { id: closeHover; cursorShape: Qt.PointingHandCursor }
          MouseArea { anchors.fill: parent; onClicked: Popups.closeAll() }
        }
      }

      Rectangle {
        width: parent.width
        height: 1
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
      }

      Flickable {
        id: scroll
        width: parent.width
        height: parent.height - y
        contentWidth: width
        contentHeight: contentColumn.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: contentColumn
          width: scroll.width
          spacing: 16

          Column {
            width: parent.width
            spacing: 8

            Text {
              text: "Hyprland"
              color: Theme.text
              font.pixelSize: 12
              font.bold: true
            }

            Grid {
              width: parent.width
              columns: 3
              rowSpacing: 8
              columnSpacing: 8

              Repeater {
                model: hyprFiles
                delegate: dotfileTile
              }
            }
          }

          Column {
            width: parent.width
            spacing: 8

            Text {
              text: "Shell and UI"
              color: Theme.text
              font.pixelSize: 12
              font.bold: true
            }

            Grid {
              width: parent.width
              columns: 3
              rowSpacing: 8
              columnSpacing: 8

              Repeater {
                model: uiFiles
                delegate: dotfileTile
              }
            }
          }

          Column {
            width: parent.width
            spacing: 8

            Text {
              text: "Apps"
              color: Theme.text
              font.pixelSize: 12
              font.bold: true
            }

            Grid {
              width: parent.width
              columns: 3
              rowSpacing: 8
              columnSpacing: 8

              Repeater {
                model: appFiles
                delegate: dotfileTile
              }
            }
          }

          Column {
            width: parent.width
            spacing: 8

            Text {
              text: "Ryoku"
              color: Theme.text
              font.pixelSize: 12
              font.bold: true
            }

            Grid {
              width: parent.width
              columns: 3
              rowSpacing: 8
              columnSpacing: 8

              Repeater {
                model: ryokuFiles
                delegate: dotfileTile
              }
            }
          }
        }
      }
    }
  }

  Component {
    id: dotfileTile

    Rectangle {
      id: tile

      required property string label
      required property string hint
      required property string icon
      required property string path
      required property color accent

      width: parent ? (parent.width - parent.columnSpacing * (parent.columns - 1)) / parent.columns : 0
      height: 48
      radius: 8
      color: hover.hovered ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.17)
                           : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.045)
      border.width: 1
      border.color: hover.hovered ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.48)
                                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
      scale: hover.hovered ? 1.018 : 1

      Behavior on color { ColorAnimation { duration: 130 } }
      Behavior on border.color { ColorAnimation { duration: 130 } }
      Behavior on scale {
        enabled: !Theme.staticMode
        NumberAnimation { duration: Theme.motionEffectsDuration; easing.type: Easing.OutCubic }
      }

      Row {
        anchors {
          fill: parent
          leftMargin: 9
          rightMargin: 10
        }
        spacing: 8

        Rectangle {
          id: iconBadge
          width: 28
          height: 28
          radius: 9
          anchors.verticalCenter: parent.verticalCenter
          color: Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, hover.hovered ? 0.28 : 0.15)

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
        onClicked: root.openDotfile(tile.path)
      }
    }
  }
}
