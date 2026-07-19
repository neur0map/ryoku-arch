//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import "Singletons"
import Ryoku.Ui

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
    // Frost the desktop behind the palette while it is open, to the strength the
    // App Launcher page sets (LauncherConfig.bgBlur, px; 0 = off). Hyprland blur
    // is a single global knob (no per-layer size), so this reads the live blur as
    // the baseline on open, drives it to that strength, and restores the exact
    // baseline on hide -- frosting even when blur is off globally. The low-power
    // switch (weak GPUs) suppresses it. Runtime config goes through `hyprctl eval`.
    //
    // All writes serialize through blurWriter: the force (open) and restore
    // (close) were independent fire-and-forget evals with no ordering guarantee,
    // so a slower compositor could apply them reversed and strand blur forced-on
    // after close, flickering through the reorder. The baseline is read only from
    // a drained compositor and only when well-formed, so a mid-transition or a
    // failed read can never become a wrong, sticky baseline.
    property bool blurForced: false
    property bool blurKnown:  false
    property bool savedBlurEnabled: false
    property int  savedBlurSize: 0

    // serialized writer: one `hyprctl eval` at a time. A newer request while it
    // runs replaces the pending one (only the final state matters) and fires when
    // the current write exits, so writes reach the compositor strictly in order.
    property string blurPending: ""
    Process {
        id: blurWriter
        onRunningChanged: {
            if (running || root.blurPending === "")
                return;
            var next = root.blurPending;
            root.blurPending = "";
            command = ["hyprctl", "eval", next];
            running = true;
        }
    }
    function evalBlur(enabled, size) {
        var cmd = "hl.config({ decoration = { blur = { enabled = " + (enabled ? "true" : "false")
            + ", size = " + Math.max(1, size) + " } } })";
        if (blurWriter.running) {
            root.blurPending = cmd;
            return;
        }
        blurWriter.command = ["hyprctl", "eval", cmd];
        blurWriter.running = true;
    }

    function forceBackdropBlur() {
        root.blurForced = true;
        var want = LauncherConfig.bgBlur | 0;
        root.evalBlur(want > 0, want);
    }
    function applyBackdropBlur() {
        if (Performance.blurDisabled || root.blurForced)
            return;
        // Read the true baseline only once the writer has fully drained (the
        // compositor now reflects the real blur); while a restore is still in
        // flight, reuse the baseline the last clean read captured.
        if (!blurWriter.running && root.blurPending === "")
            blurProbe.running = true;
        else if (root.blurKnown)
            root.forceBackdropBlur();
    }
    function restoreBackdropBlur() {
        if (!root.blurForced)
            return;
        root.blurForced = false;
        root.evalBlur(root.savedBlurEnabled, root.savedBlurSize);
    }

    // Read the live compositor blur (the real baseline to put back), then push
    // the launcher's strength. A closed palette or a malformed read leaves global
    // blur untouched, so the launcher never strands a guessed value in the config.
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
                if (typeof en.bool !== "boolean" || typeof sz.int !== "number")
                    return;
                root.savedBlurEnabled = en.bool;
                root.savedBlurSize = sz.int;
                root.blurKnown = true;
                root.forceBackdropBlur();
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

            // Ryoku brand grain over the palette, matching the desktop.
            Grain { anchors.fill: parent; z: 10000; opacity: 0.09 }

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
