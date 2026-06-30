//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"

// The standalone Ryoku command palette: one centered layer-shell overlay, resident
// and hidden at rest, shown on `ryoku-shell launcher`. Toggled over a command
// socket (keybind hot path) with an IpcHandler fallback, mirroring the pill.
ShellRoot {
    id: root

    property string openMon: ""
    readonly property bool open: openMon !== ""

    function focusedMonitor() {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : (Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "");
    }

    function show(mon) {
        root.openMon = (mon && mon.length) ? mon : root.focusedMonitor();
    }
    function hide() {
        root.openMon = "";
    }
    function toggle(mon) {
        if (root.open)
            root.hide();
        else
            root.show(mon);
    }

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-launcher.sock"

    // "<fn> [mon]" from the daemon's fast path; returns false on an unknown
    // command so the daemon falls back to the qs ipc client.
    function runCommand(line) {
        var parts = line.trim().split(" ");
        var fn = parts[0];
        var mon = parts.length > 1 ? parts[1] : "";
        switch (fn) {
        case "toggle": root.toggle(mon); return true;
        case "show":   root.show(mon); return true;
        case "hide":   root.hide(); return true;
        default:       return false;
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(mon: string): void { root.toggle(mon); }
        function show(mon: string): void { root.show(mon); }
        function hide(): void { root.hide(); }
    }

    SocketServer {
        active: true
        path: root.sockPath
        handler: Socket {
            id: cmdSock
            parser: SplitParser {
                onRead: line => cmdSock.write((root.runCommand(line) ? "ok" : "err") + "\n")
            }
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            // cap the monitor-derived scale so a tall display doesn't balloon the
            // palette; 1.0 at 1080p, at most 1.2 on bigger screens, times fontScale.
            readonly property real s: Math.min(1.2, (modelData ? modelData.height / 1080 : 1)) * Math.max(0.8, Math.min(1.4, Config.fontScale))
            readonly property bool shown: root.openMon === modelData.name

            screen: modelData
            visible: shown || closing.running
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.namespace: "launcher"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            anchors { top: true; bottom: true; left: true; right: true }

            // a brief grace so the close morph can play before the window drops.
            Timer { id: closing; interval: Motion.window; repeat: false }
            onShownChanged: if (!shown) closing.restart()

            // dim + click-out scrim.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
                opacity: win.shown ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent; onClicked: root.hide() }
            }

            Launcher {
                id: launcher
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                anchors.topMargin: Math.round((parent.height - implicitHeight) * 0.32)
                s: win.s
                shown: win.shown
                onRequestClose: root.hide()
            }
        }
    }
}
