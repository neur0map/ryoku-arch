import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../"

PanelWindow {
  id: root

  Binding { target: Popups; property: "dotfilesVisible"; value: modal.visible }

  readonly property int modalWidth: 790
  readonly property int modalHeight: 540
  readonly property string homeDir: Quickshell.env("HOME")

  property bool windowVisible: false
  property real openProgress: Popups.dotfilesOpen ? 1 : 0
  property string selectedSection: "hypr"
  property string searchQuery: ""

  onSearchQueryChanged: refreshSearchResults()

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
        root.searchQuery = ""
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

  function activeTitle() {
    if (root.searchQuery.trim() !== "") return "Search results"

    switch (root.selectedSection) {
    case "ui": return "Shell and UI"
    case "apps": return "Applications"
    case "ryoku": return "Ryoku"
    default: return "Hyprland"
    }
  }

  function activeHint() {
    if (root.searchQuery.trim() !== "") return "Matching dotfiles across every customization section."

    switch (root.selectedSection) {
    case "ui": return "Quickshell, notifications, launcher, and session environment."
    case "apps": return "Terminal and system app configuration."
    case "ryoku": return "Hooks, menu extensions, and theme templates."
    default: return "Compositor, displays, input, keybindings, and lock behavior."
    }
  }

  function activeModel() {
    switch (root.selectedSection) {
    case "ui": return uiFiles
    case "apps": return appFiles
    case "ryoku": return ryokuFiles
    default: return hyprFiles
    }
  }

  function fileMatches(label, hint, path) {
    var query = root.searchQuery.trim().toLowerCase()
    if (query === "") return true

    return label.toLowerCase().indexOf(query) !== -1
        || hint.toLowerCase().indexOf(query) !== -1
        || path.toLowerCase().indexOf(query) !== -1
  }

  function filteredCount() {
    return root.searchQuery.trim() === "" ? activeModel().count : searchFiles.count
  }

  function appendSearchMatches(model, sectionLabel) {
    for (var i = 0; i < model.count; i++) {
      var item = model.get(i)
      if (!fileMatches(item.label, item.hint, item.path)) continue

      searchFiles.append({
        "label": item.label,
        "hint": sectionLabel + " / " + item.hint,
        "icon": item.icon,
        "path": item.path,
        "accent": item.accent
      })
    }
  }

  function refreshSearchResults() {
    searchFiles.clear()
    if (root.searchQuery.trim() === "") return

    appendSearchMatches(hyprFiles, "Hyprland")
    appendSearchMatches(uiFiles, "Shell and UI")
    appendSearchMatches(appFiles, "Applications")
    appendSearchMatches(ryokuFiles, "Ryoku")
  }

  function openDotfile(path) {
    var target = root.absolutePath(path)
    if (target === "") return

    actionRunner.command = ["ryoku-launch-editor", target]
    actionRunner.running = true
    Popups.closeAll()
  }

  ListModel {
    id: categories

    ListElement { key: "hypr";  label: "Hyprland";     hint: "Window system"; icon: ""; fileCount: 10; accent: "#91d7e3" }
    ListElement { key: "ui";    label: "Shell and UI"; icon: "󱂬"; hint: "Ryoku surface"; fileCount: 14; accent: "#8bd5ca" }
    ListElement { key: "apps";  label: "Apps";         icon: ""; hint: "Daily tools";   fileCount: 17; accent: "#c6a0f6" }
    ListElement { key: "ryoku"; label: "Ryoku";        icon: "力"; hint: "Hooks";         fileCount: 8; accent: "#f5bde6" }
  }

  ListModel {
    id: hyprFiles

    ListElement { label: "Hyprland";   hint: "Main entry";  icon: ""; path: ".config/hypr/hyprland.conf"; accent: "#91d7e3" }
    ListElement { label: "Monitors";   hint: "Displays";    icon: "󰍹"; path: ".config/hypr/monitors.conf"; accent: "#7dc4e4" }
    ListElement { label: "Keybinds";   hint: "Shortcuts";   icon: "󰌌"; path: ".config/hypr/bindings.conf"; accent: "#8aadf4" }
    ListElement { label: "Input";      hint: "Keyboard";    icon: "󰌌"; path: ".config/hypr/input.conf"; accent: "#a6da95" }
    ListElement { label: "Look";       hint: "Gaps, blur";  icon: "󰉼"; path: ".config/hypr/looknfeel.conf"; accent: "#c6a0f6" }
    ListElement { label: "Autostart";  hint: "Startup";     icon: "󰐊"; path: ".config/hypr/autostart.conf"; accent: "#f5bde6" }
    ListElement { label: "Hypridle";   hint: "Idle";        icon: "󰒲"; path: ".config/hypr/hypridle.conf"; accent: "#eed49f" }
    ListElement { label: "Hyprlock";   hint: "Lock screen"; icon: "󰌾"; path: ".config/hypr/hyprlock.conf"; accent: "#ed8796" }
    ListElement { label: "Hyprsunset"; hint: "Night color"; icon: "󰔎"; path: ".config/hypr/hyprsunset.conf"; accent: "#f5a97f" }
    ListElement { label: "XDPortal";   hint: "Screen share"; icon: "󰍹"; path: ".config/hypr/xdph.conf"; accent: "#8bd5ca" }
  }

  ListModel {
    id: uiFiles

    ListElement { label: "Quickshell"; icon: "󱂬"; hint: "Shell config";  path: ".config/quickshell/ryoku/config/Config.qml"; accent: "#8bd5ca" }
    ListElement { label: "Shell Root"; icon: "󰘳"; hint: "QML entry";     path: ".config/quickshell/ryoku/shell.qml"; accent: "#91d7e3" }
    ListElement { label: "Mako";       icon: "󰍡"; hint: "Notifications"; path: ".config/mako/core.ini"; accent: "#f5bde6" }
    ListElement { label: "SwayOSD";    icon: "󰕾"; hint: "Controls";      path: ".config/swayosd/config.toml"; accent: "#eed49f" }
    ListElement { label: "OSD Style";  icon: "󰉼"; hint: "Controls CSS";  path: ".config/swayosd/style.css"; accent: "#f5a97f" }
    ListElement { label: "Tofi";       icon: "󰀻"; hint: "Launcher";      path: ".config/tofi/config"; accent: "#a6da95" }
    ListElement { label: "UWSM";       icon: "󰒓"; hint: "Environment";   path: ".config/uwsm/default"; accent: "#8aadf4" }
    ListElement { label: "UWSM Env";   icon: "󰒓"; hint: "Session vars";  path: ".config/uwsm/env"; accent: "#91d7e3" }
    ListElement { label: "Share Pick"; icon: "󰹑"; hint: "Portal picker"; path: ".config/hyprland-preview-share-picker/config.yaml"; accent: "#c6a0f6" }
    ListElement { label: "Waybar";     icon: "󰍜"; hint: "Legacy bar";    path: ".config/waybar/config.jsonc"; accent: "#ed8796" }
    ListElement { label: "Waybar CSS"; icon: "󰉼"; hint: "Legacy style";  path: ".config/waybar/style.css"; accent: "#f5bde6" }
    ListElement { label: "Fonts";      icon: "󰛖"; hint: "Fontconfig";    path: ".config/fontconfig/fonts.conf"; accent: "#eed49f" }
    ListElement { label: "Fcitx Env";  icon: "󰌌"; hint: "Input method";  path: ".config/environment.d/fcitx.conf"; accent: "#8aadf4" }
    ListElement { label: "XCompose";   icon: "󰌌"; hint: "Compose keys";  path: ".XCompose"; accent: "#91d7e3" }
  }

  ListModel {
    id: appFiles

    ListElement { label: "Ghostty";   icon: ""; hint: "Terminal";     path: ".config/ghostty/config"; accent: "#91d7e3" }
    ListElement { label: "Alacritty"; icon: ""; hint: "Terminal";     path: ".config/alacritty/alacritty.toml"; accent: "#8aadf4" }
    ListElement { label: "Kitty";     icon: ""; hint: "Terminal";     path: ".config/kitty/kitty.conf"; accent: "#c6a0f6" }
    ListElement { label: "Btop";      icon: "󰍛"; hint: "Activity";     path: ".config/btop/btop.conf"; accent: "#a6da95" }
    ListElement { label: "Fastfetch"; icon: "󰇅"; hint: "System info";  path: ".config/fastfetch/config.jsonc"; accent: "#f5a97f" }
    ListElement { label: "Git";       icon: "󰊢"; hint: "Git config";   path: ".config/git/config"; accent: "#ed8796" }
    ListElement { label: "Tmux";      icon: ""; hint: "Terminal mux"; path: ".config/tmux/tmux.conf"; accent: "#eed49f" }
    ListElement { label: "Starship";  icon: "󰄛"; hint: "Prompt";       path: ".config/starship.toml"; accent: "#8bd5ca" }
    ListElement { label: "Lazygit";   icon: "󰊢"; hint: "Git TUI";      path: ".config/lazygit/config.yml"; accent: "#c6a0f6" }
    ListElement { label: "Voxtype";   icon: "󰍬"; hint: "Voice input";  path: ".config/voxtype/config.toml"; accent: "#f5bde6" }
    ListElement { label: "Chromium";  icon: ""; hint: "Flags";        path: ".config/chromium-flags.conf"; accent: "#8aadf4" }
    ListElement { label: "Brave";     icon: "󰖟"; hint: "Flags";        path: ".config/brave-flags.conf"; accent: "#f5a97f" }
    ListElement { label: "IMV";       icon: "󰋩"; hint: "Image viewer"; path: ".config/imv/config"; accent: "#8bd5ca" }
    ListElement { label: "Wiremix";   icon: "󰕾"; hint: "Audio mixer";  path: ".config/wiremix/wiremix.toml"; accent: "#ed8796" }
    ListElement { label: "Defaults";  icon: "󰈙"; hint: "App chooser";  path: ".config/mimeapps.list"; accent: "#a6da95" }
    ListElement { label: "Terminals"; icon: ""; hint: "Default list";  path: ".config/xdg-terminals.list"; accent: "#eed49f" }
  }

  ListModel {
    id: ryokuFiles

    ListElement { label: "Menu Hook";      icon: "󰈙"; hint: "Extensions"; path: ".config/ryoku/extensions/menu.sh"; accent: "#8bd5ca" }
    ListElement { label: "Post Update";    icon: "󰚰"; hint: "Hook";       path: ".config/ryoku/hooks/post-update"; accent: "#c6a0f6" }
    ListElement { label: "Theme Hook";     icon: "󰔎"; hint: "Hook";       path: ".config/ryoku/hooks/theme-set"; accent: "#f5bde6" }
    ListElement { label: "Theme Template"; icon: "󰈔"; hint: "Sample";     path: ".config/ryoku/themed/alacritty.toml.tpl.sample"; accent: "#91d7e3" }
    ListElement { label: "Battery Hook";   icon: "󰂄"; hint: "Hook";       path: ".config/ryoku/hooks/battery-low"; accent: "#eed49f" }
    ListElement { label: "Font Hook";      icon: "󰛖"; hint: "Hook";       path: ".config/ryoku/hooks/font-set"; accent: "#8aadf4" }
    ListElement { label: "About Text";     icon: "󰋼"; hint: "Branding";   path: ".config/ryoku/branding/about.txt"; accent: "#8bd5ca" }
    ListElement { label: "Screen Text";    icon: "󰹑"; hint: "Branding";   path: ".config/ryoku/branding/screensaver.txt"; accent: "#f5a97f" }
  }

  ListModel {
    id: searchFiles
  }

  Rectangle {
    anchors.fill: parent
    color: "#000000"
    opacity: root.openProgress * 0.52

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

    width: Math.max(0, Math.min(root.modalWidth, parent.width - 56))
    height: Math.max(0, Math.min(root.modalHeight, parent.height - 96))
    x: (parent.width - width) / 2
    y: (parent.height - height) / 2 + (1 - root.openProgress) * 18
    visible: root.openProgress > 0
    opacity: root.openProgress
    scale: 0.975 + 0.025 * root.openProgress
    radius: 10
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.98)
    border.width: 1
    border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.30)
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

    Rectangle {
      id: hero

      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        margins: 14
      }
      height: 98
      radius: 8
      color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.09)
      border.width: 1
      border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.22)
      clip: true

      Rectangle {
        width: 5
        anchors {
          top: parent.top
          bottom: parent.bottom
          left: parent.left
        }
        color: Theme.active
        opacity: 0.86
      }

      Item {
        anchors {
          fill: parent
          leftMargin: 24
          rightMargin: 54
          topMargin: 16
          bottomMargin: 16
        }

        Text {
          id: heroTitle
          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
          }
          text: "Dotfile Control"
          color: Theme.text
          font.pixelSize: 20
          font.bold: true
          elide: Text.ElideRight
        }

        Text {
          anchors {
            top: heroTitle.bottom
            topMargin: 6
            left: parent.left
            right: parent.right
          }
          text: "Modify at your own risk. Broken config can affect login, input, keybindings, or shell startup."
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.66)
          font.pixelSize: 11
          wrapMode: Text.WordWrap
          lineHeight: 1.16
        }
      }

      Rectangle {
        width: 30
        height: 30
        radius: 7
        anchors {
          top: parent.top
          right: parent.right
          topMargin: 12
          rightMargin: 12
        }
        color: closeHover.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18)
                                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)

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

    Row {
      id: body

      anchors {
        top: hero.bottom
        left: parent.left
        right: parent.right
        bottom: parent.bottom
        topMargin: 12
        leftMargin: 14
        rightMargin: 14
        bottomMargin: 14
      }
      spacing: 10

      Rectangle {
        id: categoryRail

        width: 190
        height: parent.height
        radius: 8
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.030)
        border.width: 1
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

        Column {
          anchors {
            fill: parent
            margins: 8
          }
          spacing: 6

          Text {
            width: parent.width
            text: "Sections"
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.52)
            font.pixelSize: 10
            font.bold: true
            elide: Text.ElideRight
          }

          Repeater {
            model: categories

            delegate: Rectangle {
              id: sectionButton

              required property string key
              required property string label
              required property string hint
              required property string icon
              required property int fileCount
              required property color accent

              readonly property bool active: root.selectedSection === sectionButton.key

              width: parent.width
              height: 48
              radius: 6
              color: sectionButton.active ? Qt.rgba(sectionButton.accent.r, sectionButton.accent.g, sectionButton.accent.b, 0.18)
                                          : sectionHover.hovered ? Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
                                                                 : "transparent"
              border.width: sectionButton.active ? 1 : 0
              border.color: Qt.rgba(sectionButton.accent.r, sectionButton.accent.g, sectionButton.accent.b, 0.36)

              Behavior on color { ColorAnimation { duration: 130 } }

              Rectangle {
                width: 3
                radius: 2
                anchors {
                  top: parent.top
                  bottom: parent.bottom
                  left: parent.left
                  topMargin: 10
                  bottomMargin: 10
                }
                color: sectionButton.accent
                opacity: sectionButton.active ? 1 : 0
              }

              Column {
                anchors {
                  left: parent.left
                  right: parent.right
                  verticalCenter: parent.verticalCenter
                  leftMargin: 12
                  rightMargin: 10
                }
                spacing: -1

                Text {
                  width: parent.width
                  text: sectionButton.label
                  color: Theme.text
                  font.pixelSize: 11
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  width: parent.width
                  text: sectionButton.hint
                  color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.43)
                  font.pixelSize: 9
                  elide: Text.ElideRight
                }
              }

              HoverHandler {
                id: sectionHover
                cursorShape: Qt.PointingHandCursor
              }

              MouseArea {
                anchors.fill: parent
                onClicked: root.selectedSection = sectionButton.key
              }
            }
          }
        }
      }

      Rectangle {
        id: filePane

        width: parent.width - categoryRail.width - parent.spacing
        height: parent.height
        radius: 8
        color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.024)
        border.width: 1
        border.color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

        Item {
          id: fileHeader

          anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: 14
          }
          height: 48

          Column {
            anchors {
              left: parent.left
              right: searchBar.left
              rightMargin: 12
              verticalCenter: parent.verticalCenter
            }
            spacing: -1

            Text {
              width: parent.width
              text: root.activeTitle()
              color: Theme.text
              font.pixelSize: 15
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width
              text: root.activeHint()
              color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.47)
              font.pixelSize: 10
              elide: Text.ElideRight
            }
          }

          Rectangle {
            id: searchBar
            width: 176
            height: 26
            anchors {
              right: parent.right
              verticalCenter: parent.verticalCenter
            }
            radius: 6
            color: searchInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.10)
                                           : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.035)
            border.width: 1
            border.color: searchInput.activeFocus ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.32)
                                                  : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.065)

            Behavior on color { ColorAnimation { duration: 130 } }
            Behavior on border.color { ColorAnimation { duration: 130 } }

            Text {
              anchors {
                left: parent.left
                leftMargin: 9
                verticalCenter: parent.verticalCenter
              }
              text: "Search"
              visible: searchInput.text === ""
              color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.34)
              font.pixelSize: 10
            }

            TextInput {
              id: searchInput
              anchors {
                fill: parent
                leftMargin: 9
                rightMargin: 9
              }
              verticalAlignment: TextInput.AlignVCenter
              color: Theme.text
              selectionColor: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35)
              selectedTextColor: Theme.text
              font.pixelSize: 10
              clip: true
              focus: false
              text: root.searchQuery
              onTextChanged: root.searchQuery = text
              Keys.onEscapePressed: {
                if (text === "") {
                  Popups.closeAll()
                } else {
                  text = ""
                }
              }
            }
          }
        }

        Rectangle {
          anchors {
            top: fileHeader.bottom
            left: parent.left
            right: parent.right
            topMargin: 2
            leftMargin: 14
            rightMargin: 14
          }
          height: 1
          color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.07)
        }

        Flickable {
          id: fileList

          anchors {
            top: fileHeader.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            topMargin: 12
            leftMargin: 14
            rightMargin: 14
            bottomMargin: 14
          }
          contentWidth: width
          contentHeight: filesColumn.implicitHeight
          clip: true
          boundsBehavior: Flickable.StopAtBounds
          property int count: root.filteredCount()

          Column {
            id: filesColumn

            width: fileList.width
            spacing: 8

            Repeater {
              model: root.searchQuery.trim() === "" ? root.activeModel() : searchFiles
              delegate: dotfileRow
            }
          }
        }
      }
    }
  }

  Component {
    id: dotfileRow

    Rectangle {
      id: row

      required property string label
      required property string hint
      required property string icon
      required property string path
      required property color accent

      readonly property bool matchesSearch: root.fileMatches(row.label, row.hint, row.path)

      width: filesColumn.width
      height: row.matchesSearch ? 54 : 0
      visible: row.matchesSearch
      radius: 6
      color: rowHover.hovered ? Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.14)
                              : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.034)
      border.width: 1
      border.color: rowHover.hovered ? Qt.rgba(row.accent.r, row.accent.g, row.accent.b, 0.40)
                                     : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.055)

      Behavior on color { ColorAnimation { duration: 130 } }
      Behavior on border.color { ColorAnimation { duration: 130 } }

      Row {
        anchors {
          fill: parent
          leftMargin: 12
          rightMargin: 12
        }
        spacing: 8

        Rectangle {
          id: fileMark
          width: 4
          height: 28
          radius: 2
          anchors.verticalCenter: parent.verticalCenter
          color: row.accent
          opacity: rowHover.hovered ? 0.95 : 0.62
        }

        Column {
          width: parent.width - fileMark.width - parent.spacing - openAction.width - 8
          anchors.verticalCenter: parent.verticalCenter
          spacing: 0

          Row {
            width: parent.width
            spacing: 8

            Text {
              width: Math.min(130, parent.width * 0.42)
              text: row.label
              color: Theme.text
              font.pixelSize: 12
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              width: parent.width - 138
              text: row.hint
              color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.47)
              font.pixelSize: 10
              elide: Text.ElideRight
            }
          }

          Text {
            width: parent.width
            text: "~/" + row.path
            color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.38)
            font.pixelSize: 9
            elide: Text.ElideMiddle
          }
        }

        Text {
          id: openAction
          width: 42
          anchors.verticalCenter: parent.verticalCenter
          text: "Open"
          color: rowHover.hovered ? Theme.text : Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.46)
          font.pixelSize: 10
          font.bold: rowHover.hovered
          horizontalAlignment: Text.AlignRight
        }
      }

      HoverHandler {
        id: rowHover
        cursorShape: Qt.PointingHandCursor
      }

      MouseArea {
        anchors.fill: parent
        onClicked: root.openDotfile(row.path)
      }
    }
  }
}
