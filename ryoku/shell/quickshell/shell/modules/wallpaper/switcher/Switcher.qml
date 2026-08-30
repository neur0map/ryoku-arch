pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Ryoku.Ui.Singletons
import "Singletons"

/**
 * Ryoku wallpaper switcher: a full-screen overlay, one instance per monitor
 * (the shell root's per-screen scope constructs it with `screen`). It rests
 * resident and hidden, shown while `active` (the controller binds it to
 * ShellState.wallpaperSwitcherOpen). Staying resident drops the per-open cold
 * start; the heavy thumbnail grid still loads only while open (the body Loader
 * unloads on close), so a hidden switcher holds no textures and the basic
 * render loop draws nothing.
 *
 * Images and videos share one grid, grouped by colour the way skwd-wall does;
 * arrows/Tab move the pick, a colour swatch or the type row filters, Enter or a
 * click sets it, Esc dismisses. The card and accent mirror the shell chrome
 * through the local Scheme singleton. Click-out and Esc raise `requestClose`;
 * the controller clears the ShellState flag (this module never touches it).
 */
Item {
    id: root

    // The monitor this overlay covers, supplied by the shell root's per-screen
    // scope; only the focused monitor carries the card and keyboard.
    required property var screen
    // Driven by the controller (ShellState.wallpaperSwitcherOpen). Refresh the
    // wall/theme lists each time the switcher opens.
    property bool active: false
    // Raised by click-out and Esc so the controller can clear the open flag.
    signal requestClose()

    onActiveChanged: if (root.active)
        Walls.refresh()

    readonly property string focusedMon: {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : "";
    }

    PanelWindow {
        id: win
        readonly property real s: Math.min(1.08, (root.screen ? root.screen.height / 1080 : 1)) * Math.max(0.8, Math.min(1.25, Config.fontScale)) * Tokens.uiScaleFor(root.screen ? root.screen.name : "")
        // root.screen is null while its output is being torn down, and this feeds
        // keyboardFocus below: an unguarded read left the last value standing.
        readonly property bool isFocused: !root.focusedMon || (root.screen ? root.focusedMon === root.screen.name : false)
        readonly property bool shown: root.active

        screen: root.screen
        visible: shown || closing.running
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "ryoku-wallpaper-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: (shown && isFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        // Hold the layer mapped through the outro, then unmap once it settles.
        Timer { id: closing; interval: Motion.window; repeat: false }
        onShownChanged: if (!shown) closing.restart()

        // Click-out catcher; no dim (the frosted card carries the separation).
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            opacity: win.shown ? 1 : 0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
            MouseArea { anchors.fill: parent; onClicked: root.requestClose() }
        }

        // Only the focused monitor carries the card + keyboard. The heavy grid
        // loads while shown and unloads after the outro, so a hidden resident
        // switcher keeps no thumbnails in memory.
        Loader {
            anchors.fill: parent
            active: win.isFocused && (win.shown || closing.running)
            sourceComponent: SwitcherBody {
                s: win.s
                active: win.shown
                screenName: root.screen ? root.screen.name : ""
                onRequestClose: root.requestClose()

                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.98
                Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
                Behavior on scale { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
            }
        }
    }
}
