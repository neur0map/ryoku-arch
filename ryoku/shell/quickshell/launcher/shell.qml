//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "Singletons"

// The standalone Ryoku command palette: one centered layer-shell overlay, resident
// and hidden at rest, shown on `ryoku-shell launcher`. Toggled over a command
// socket (keybind hot path) with an IpcHandler fallback, mirroring the pill.
ShellRoot {
    id: root

    property string openMon: ""
    readonly property bool open: openMon !== ""

    // Report open/close to the shell daemon so its opt-in idle-park worker
    // (unloadLauncherWhenIdle) can free this resident palette after a grace of
    // being hidden and respawn it on the next open. A no-op when the flag is off;
    // the daemon just records the state.
    onOpenChanged: {
        Quickshell.execDetached(["ryoku-shell", "state", "launcher", open ? "1" : "0"]);
        if (open)
            root.applyBackdropBlur();
        else
            root.restoreBackdropBlur();
    }

    // --- backdrop blur -----------------------------------------------------
    // Frost the desktop behind the palette while it is open, by how much the App
    // Launcher page's slider says (LauncherConfig.bgBlur, px; 0 = off). Hyprland
    // blur size and enable are global (no per-layer size), so this reads the live
    // blur on open, drives it to the chosen strength, and puts it back on hide,
    // turning blur on even when the user keeps it off globally. The low-power
    // blur switch (weak GPUs) suppresses it. Hyprland's Lua parser takes runtime
    // config through `hyprctl eval`, not `keyword`.
    property bool blurForced: false
    property bool savedBlurEnabled: false
    property int  savedBlurSize: 5

    function evalBlur(enabled, size) {
        Quickshell.execDetached(["hyprctl", "eval",
            "hl.config({ decoration = { blur = { enabled = " + (enabled ? "true" : "false")
                + ", size = " + Math.max(1, size) + " } } })"]);
    }
    function applyBackdropBlur() {
        if (Performance.blurDisabled)
            return;
        blurProbe.running = true;
    }
    function restoreBackdropBlur() {
        if (!root.blurForced)
            return;
        root.blurForced = false;
        root.evalBlur(root.savedBlurEnabled, root.savedBlurSize);
    }

    // Read the live compositor blur once per open (the real baseline to put
    // back), then push the launcher's strength. Ignored if the palette closed
    // before the read returned.
    Process {
        id: blurProbe
        command: ["sh", "-c", "hyprctl getoption -j decoration:blur:enabled; hyprctl getoption -j decoration:blur:size"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.open)
                    return;
                var en, sz;
                try {
                    var lines = this.text.trim().split("\n");
                    en = JSON.parse(lines[0]);
                    sz = JSON.parse(lines[1]);
                } catch (e) {
                    return;
                }
                if (!root.blurForced) {
                    root.savedBlurEnabled = en.bool === true;
                    root.savedBlurSize = sz.int > 0 ? sz.int : 5;
                }
                root.blurForced = true;
                var want = LauncherConfig.bgBlur | 0;
                root.evalBlur(want > 0, want);
            }
        }
    }

    // Any MPRIS player actively playing. Gates the now-playing wave backdrop's
    // cava process (Spectrum) so it runs only while the launcher is open AND
    // there is real audio, never on a hidden or silent palette.
    readonly property bool anyPlaying: {
        var list = Mpris.players.values;
        if (!list)
            return false;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].isPlaying)
                return true;
        return false;
    }

    Binding {
        target: Spectrum
        property: "active"
        value: root.open && root.anyPlaying
    }

    // launcher weather units from the config: "auto" follows the locale.
    Binding {
        target: Weather
        property: "unitOverride"
        value: LauncherConfig.weatherUnit === "auto" ? "" : LauncherConfig.weatherUnit
    }

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

    // the Launcher body on the monitor currently (or last) shown; lets the
    // socket's `state` command snapshot what the palette is displaying.
    property var activeLauncher: null
    property var activeBt: null

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
                onRead: line => {
                    var l = line.trim();
                    if (l === "state") {
                        var dump = root.activeLauncher ? root.activeLauncher.stateDump() : {};
                        dump.open = root.open;
                        dump.monitor = root.openMon;
                        dump.btConnected = root.activeBt ? root.activeBt.connected.length : 0;
                        cmdSock.write(JSON.stringify(dump) + "\n");
                    } else {
                        cmdSock.write((root.runCommand(l) ? "ok" : "err") + "\n");
                    }
                }
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
            // hold the grab until the window unmaps (end of the close morph).
            // dropping it while still mapped strands the keyboard on the dead
            // layer: the app looks focused but can't type until a real focus
            // change. unmapping with the grab held hands the keyboard back.
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

            anchors { top: true; bottom: true; left: true; right: true }

            // a brief grace so the close morph can play before the window drops.
            Timer { id: closing; interval: Motion.window; repeat: false }
            onShownChanged: {
                if (shown) {
                    root.activeLauncher = launcher;
                    root.activeBt = btBubbles;
                } else {
                    closing.restart();
                }
            }

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
                // off resting height, not the live one, so growing results push the
                // body down while the search row holds its position.
                anchors.topMargin: Math.round((parent.height - launcher.restingHeight) * 0.32)
                s: win.s
                shown: win.shown
                onRequestClose: root.hide()
            }

            // Detached Bluetooth bubbles under the palette: one square card
            // per connected device (BtConnections renders nothing otherwise),
            // riding the same open/close morph as the card above.
            BtConnections {
                id: btBubbles
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: launcher.bottom
                anchors.topMargin: 10 * win.s
                width: launcher.width
                s: win.s
                transformOrigin: Item.Top
                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.92
                Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Easing.OutCubic } }
                Behavior on scale {
                    NumberAnimation { duration: Motion.window; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
                }
            }
        }
    }
}
