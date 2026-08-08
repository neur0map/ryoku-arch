//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../../shared/Singletons"
import "../../shared/providers" as SharedProviders
import "." as MainVariant

// Main's compact command palette: a separate search row over an image-backed
// dashboard, loaded behind the stable launcher selector.
Scope {
    id: root

    property string openMon: ""
    property var activeSurface: null
    property var activeLauncher: null
    property var activeBt: null
    readonly property bool open: openMon !== ""
    readonly property bool shown: open
        || (activeSurface !== null && activeSurface.visible)

    onShownChanged: {
        // Phase 10: the launcher-open daemon report (execDetached ryoku-shell state
        // launcher) is dropped; ShellState.launcherOpen owns open state now.
        if (shown)
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

    function stateDump() {
        var dump = root.activeLauncher ? root.activeLauncher.stateDump()
            : { query: "", resultCount: 0, selectedIndex: -1 };
        dump.open = root.shown;
        dump.monitor = root.openMon;
        dump.btConnected = root.activeBt ? root.activeBt.connected.length : 0;
        return dump;
    }
    SharedProviders.Providers {
        id: sharedProviders
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
            Timer { id: closing; interval: Motion.open; repeat: false }
            onShownChanged: {
                if (shown) {
                    closing.stop();
                    root.activeSurface = win;
                    root.activeLauncher = launcher;
                    root.activeBt = btBubbles;
                } else {
                    closing.restart();
                }
            }
            onVisibleChanged: {
                if (!visible && root.activeSurface === win)
                    root.activeSurface = null;
            }

            // dim + click-out scrim.
            Rectangle {
                anchors.fill: parent
                color: Qt.rgba(0, 0, 0, 0.35)
                opacity: win.shown ? 1 : 0
                visible: opacity > 0.001
                Behavior on opacity { NumberAnimation { duration: Motion.open; easing.type: Easing.OutCubic } }
                MouseArea { anchors.fill: parent; onClicked: root.hide() }
            }

            MainVariant.Launcher {
                id: launcher
                providerSet: sharedProviders
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
            MainVariant.BtConnections {
                id: btBubbles
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: launcher.bottom
                anchors.topMargin: 10 * win.s
                width: launcher.width
                s: win.s
                transformOrigin: Item.Top
                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.92
                Behavior on opacity { NumberAnimation { duration: Motion.open; easing.type: Easing.OutCubic } }
                Behavior on scale {
                    NumberAnimation { duration: Motion.open; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
                }
            }
        }
    }
}
