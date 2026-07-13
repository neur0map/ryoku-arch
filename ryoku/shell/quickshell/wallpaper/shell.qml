//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

/**
 * Ryoku wallpaper switcher: a full-screen overlay the shell daemon keeps
 * resident and hidden at rest, shown on `ryoku-shell wallpaper-switcher` (an
 * IpcHandler toggle on the keybind hot path, like the launcher and overview).
 * Staying resident drops the per-open process cold-start; the heavy thumbnail
 * grid still loads only while open (the body Loader below unloads on close), so a
 * hidden switcher holds no textures and the basic render loop draws nothing.
 *
 * Images and videos share one grid, grouped by colour the way skwd-wall does;
 * arrows/Tab move the pick, a colour swatch or the type row filters, Enter or a
 * click sets it, Esc dismisses. The card and accent mirror the shell chrome
 * through the local wallust singleton.
 */
ShellRoot {
    id: root

    property bool open: false

    // Spawned fresh per open by the daemon's `wallpaper-switcher` (under flock),
    // so the picker shows on launch and quits on close: it holds no memory while
    // idle, unlike the resident shell surfaces.
    Component.onCompleted: root.show()

    function show() {
        Walls.refresh();
        root.open = true;
    }
    function hide() {
        root.open = false;
        quitTimer.restart();
    }
    // Quit once the close animation has played, so the outro is visible and the
    // process (its scene graph and GL context) frees on close.
    Timer { id: quitTimer; interval: Motion.window + 60; onTriggered: Qt.quit() }

    readonly property string focusedMon: {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : "";
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property real s: Math.min(1.3, (modelData ? modelData.height / 1080 : 1)) * Math.max(0.8, Math.min(1.4, Config.fontScale))
            readonly property bool isFocused: !root.focusedMon || root.focusedMon === modelData.name
            readonly property bool shown: root.open

            screen: modelData
            visible: shown || closing.running
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "ryoku-wallpaper"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (shown && isFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            // Hold the layer mapped through the outro, then unmap once it settles.
            Timer { id: closing; interval: Motion.window; repeat: false }
            onShownChanged: if (!shown) closing.restart()

            // Dim scrim over the desktop; click-out dismisses.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.42)
                opacity: win.shown ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
                MouseArea { anchors.fill: parent; onClicked: root.hide() }
            }

            // Only the focused monitor carries the card + keyboard. The heavy grid
            // loads while shown and unloads after the outro, so a hidden resident
            // switcher keeps no thumbnails in memory.
            Loader {
                anchors.fill: parent
                active: win.isFocused && (win.shown || closing.running)
                sourceComponent: Switcher {
                    s: win.s
                    active: win.shown
                    onRequestClose: root.hide()

                    opacity: win.shown ? 1 : 0
                    scale: win.shown ? 1 : 0.98
                    Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
                    Behavior on scale { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
                }
            }
        }
    }
}
