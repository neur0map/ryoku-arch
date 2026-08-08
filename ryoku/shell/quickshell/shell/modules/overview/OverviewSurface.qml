pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

/**
 * Ryoku workspace overview: a full-screen expo, migrated to a per-monitor module
 * entry the single resident shell instantiates once per screen. The compositor
 * blurs the desktop behind the "overview" layer (the layer rule in
 * hyprland/modules/decoration.lua), so only the workspace cells and their live
 * window previews read on top. This screen shows its own workspaces as scaled
 * mini-desktops; only the focused monitor grabs the keyboard. Click a cell to
 * switch, click a window to focus, drag a window onto another cell to move it,
 * scroll or Tab/arrows to cycle, Esc or click-out to dismiss.
 *
 * `active` drives the reveal and window mapping; the controller binds it to this
 * monitor's ShellState.overviewOpen. `screen` is the monitor this surface draws
 * on, injected by the per-screen Variants in shell.qml.
 */
Scope {
    id: root

    // The monitor this overview surface draws on, injected per-screen by shell.qml.
    property var screen: null

    // Reveal input the controller binds to this monitor's ShellState.overviewOpen.
    property bool active: false

    // Close request (Esc / click-out). The controller resets overviewOpen; we
    // never assign `active` here, which would destroy its binding to the flag
    // and leave the overview permanently unable to reopen.
    signal requestClose()

    // Refresh Hyprland's monitor/workspace/toplevel models once when the expo
    // opens so a just-mapped window lands; the resident models are already warm,
    // so nothing polls. Phase 10: the daemon idle-park report that also lived on
    // this handler (execDetached ryoku-shell state overview) is dropped now that
    // ShellState.overviewOpen owns open/close.
    onActiveChanged: if (root.active) {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    function focusedMonitor() {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
    }
    function hide() {
        root.requestClose();
    }

    readonly property string focusedMon: {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : "";
    }

    PanelWindow {
        id: win
        readonly property real s: Math.min(1.25, (root.screen ? root.screen.height / 1080 : 1)) * Math.max(0.8, Math.min(1.4, Config.fontScale))
        readonly property bool isFocused: !root.focusedMon || root.focusedMon === (root.screen ? root.screen.name : "")
        readonly property bool shown: root.active

        screen: root.screen
        visible: shown || closing.running
        color: "transparent"
        exclusiveZone: 0
        WlrLayershell.namespace: "overview"
        WlrLayershell.layer: WlrLayer.Overlay
        // Only the focused monitor grabs the keyboard, so keys never double-fire.
        WlrLayershell.keyboardFocus: (shown && isFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        anchors { top: true; bottom: true; left: true; right: true }

        // Hold the layer mapped through the outro, then unmap once it settles.
        Timer { id: closing; interval: Motion.window; repeat: false }
        onShownChanged: {
            if (shown) {
                if (isFocused)
                    kb.forceActiveFocus();
            } else {
                closing.restart();
            }
        }

        // Dim scrim over the (compositor-blurred) desktop; click-out dismisses.
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.32)
            opacity: win.shown ? 1 : 0
            visible: opacity > 0.001
            Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
            MouseArea { anchors.fill: parent; onClicked: root.hide() }
        }

        Overview {
            id: body
            anchors.fill: parent
            s: win.s
            screenName: root.screen ? root.screen.name : ""
            active: win.shown
            // The resident models are warm, so data is ready without polling.
            dataReady: true
            focusHere: win.isFocused
            onRequestClose: root.hide()

            // reveal: fade + a small scale settle, like the launcher window.
            opacity: win.shown ? 1 : 0
            scale: win.shown ? 1 : 0.97
            Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
            Behavior on scale { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
        }

        // Keyboard: only the focused monitor's window handles keys.
        Item {
            id: kb
            anchors.fill: parent
            focus: win.shown && win.isFocused
            Keys.onPressed: (e) => {
                if (!win.isFocused)
                    return;
                var alt = (e.modifiers & Qt.AltModifier) !== 0;
                var shift = (e.modifiers & Qt.ShiftModifier) !== 0;
                if (e.key === Qt.Key_Escape) {
                    root.hide(); e.accepted = true;
                } else if (alt && (e.key === Qt.Key_Tab || e.key === Qt.Key_Right || e.key === Qt.Key_Backtab || e.key === Qt.Key_Left)) {
                    // Super+Alt+Tab: step across DESKTOPS (the top strip).
                    body.cycleDesktop((shift || e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) ? -1 : 1);
                    e.accepted = true;
                } else if (e.key === Qt.Key_Tab || e.key === Qt.Key_Right) {
                    body.cycle(shift ? -1 : 1); e.accepted = true;
                } else if (e.key === Qt.Key_Backtab || e.key === Qt.Key_Left) {
                    body.cycle(-1); e.accepted = true;
                } else if (e.key === Qt.Key_Down) {
                    body.cycle(1); e.accepted = true;
                } else if (e.key === Qt.Key_Up) {
                    body.cycle(-1); e.accepted = true;
                } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
                    body.activateSelected(); e.accepted = true;
                }
            }
        }
    }
}
