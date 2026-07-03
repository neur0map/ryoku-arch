//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = threaded
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

/**
 * Ryoku workspace overview: a full-screen, launcher-style expo launched as its
 * own `qs -c overview` instance (like the switcher and ryoshot, so it never
 * burdens the always-on pill). The compositor blurs the desktop behind it (the
 * `overview` layer rule in hyprland/modules/decoration.lua), so only the
 * workspace cells and their LIVE window previews read on top.
 *
 * Each monitor gets its own overlay showing that monitor's workspaces as scaled
 * mini-desktops, windows drawn at their real positions with a live ScreencopyView
 * texture. Click a cell to switch, click a window to focus, drag a window onto
 * another cell to move it there, scroll or Tab/arrows to cycle, Esc / click-out
 * to dismiss. Subtle Ryoku chrome: sharp corners, hairline borders, one
 * vermillion accent on the active cell.
 */
ShellRoot {
    id: root

    // Populate the models before the first frame; a fresh instance starts empty.
    Component.onCompleted: {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }
    // Belt-and-suspenders: a fresh instance's Hyprland models start empty and
    // even arrive as uninitialised stubs (workspaces with id -1, no lastIpcObject)
    // for a frame or two. Keep polling until BOTH a real workspace (id > 0) and a
    // mapped toplevel have landed, so the reactive cell grid isn't built off
    // half-loaded data. The bindings fill in as the refreshes resolve.
    Timer {
        interval: 140
        running: !root.ready
        repeat: true
        onTriggered: {
            Hyprland.refreshMonitors();
            Hyprland.refreshWorkspaces();
            Hyprland.refreshToplevels();
        }
    }
    // Ready only once a real workspace (id > 0) AND the focused monitor (with its
    // activeWorkspace) have landed. A fresh instance's monitor model arrives a few
    // frames after workspaces; gating on workspaces alone stopped the poll before
    // monitors loaded, so the overview couldn't tell which desktop was active and
    // always seeded desktop 1. Keep refreshing until both are present.
    readonly property bool ready: {
        var mons = Hyprland.monitors.values;
        var haveMon = false;
        for (var j = 0; j < mons.length; j++)
            if (mons[j] && mons[j].lastIpcObject && mons[j].lastIpcObject.activeWorkspace)
                haveMon = true;
        if (!haveMon)
            return false;
        var ws = Hyprland.workspaces.values;
        for (var i = 0; i < ws.length; i++)
            if (ws[i] && ws[i].id > 0)
                return true;
        return false;
    }

    // Intro/outro: `active` drives the content reveal; a close plays the outro
    // then quits the instance (on-demand config, so dismiss == exit).
    property bool active: false
    Component.onDestruction: {}
    Timer { id: introT; interval: 16; running: true; repeat: false; onTriggered: root.active = true }
    Timer { id: outroT; interval: 210; running: false; repeat: false; onTriggered: Qt.quit() }
    function dismiss() {
        if (!root.active && outroT.running)
            return;
        root.active = false;
        outroT.restart();
    }

    readonly property string focusedMon: {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : "";
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property real s: Math.min(1.25, (modelData ? modelData.height / 1080 : 1)) * Math.max(0.8, Math.min(1.4, Config.fontScale))
            readonly property bool isFocused: !root.focusedMon || root.focusedMon === modelData.name

            screen: modelData
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: "overview"
            WlrLayershell.layer: WlrLayer.Overlay
            // Only the focused monitor grabs the keyboard, so keys never double-fire.
            WlrLayershell.keyboardFocus: isFocused ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            // Dim scrim over the (compositor-blurred) desktop; click-out dismisses.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.32)
                opacity: root.active ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
                MouseArea { anchors.fill: parent; onClicked: root.dismiss() }
            }

            Overview {
                id: body
                anchors.fill: parent
                s: win.s
                screenName: win.modelData ? win.modelData.name : ""
                active: root.active
                dataReady: root.ready
                focusHere: win.isFocused
                onRequestClose: root.dismiss()

                // reveal: fade + a small scale settle, like the launcher window.
                opacity: root.active ? 1 : 0
                scale: root.active ? 1 : 0.97
                Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
                Behavior on scale { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
            }

            // Keyboard: only the focused monitor's window handles keys.
            Item {
                anchors.fill: parent
                focus: win.isFocused
                Component.onCompleted: if (win.isFocused) forceActiveFocus()
                Keys.onPressed: (e) => {
                    if (!win.isFocused)
                        return;
                    var alt = (e.modifiers & Qt.AltModifier) !== 0;
                    var shift = (e.modifiers & Qt.ShiftModifier) !== 0;
                    if (e.key === Qt.Key_Escape) {
                        root.dismiss(); e.accepted = true;
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
}
