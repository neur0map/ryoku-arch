//@ pragma UseQApplication
//@ pragma DefaultEnv QSG_RENDER_LOOP = basic
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "Singletons"
import Ryoku.Ui
import Ryoku.Ui.Singletons

/**
 * RyoLayer: the Super+G tool overlay. A transparent board over the desktop
 * (compositor-blurred behind, strength = Config.bgBlur) hosting the layer's
 * instrument widgets: drag to place, bracket to resize, pin to keep one on a
 * WlrLayer.Top window after the board closes. Resident and hidden at rest,
 * toggled by `ryoku-shell ryolayer` (an IpcHandler on the keybind hot path,
 * the overview pattern). Esc or click-out dismisses.
 */
ShellRoot {
    id: root

    property bool open: false

    function show() { root.open = true; }
    function hide() { root.open = false; }
    function toggle() { root.open = !root.open; }

    readonly property string focusedName: {
        var m = Hyprland.focusedMonitor;
        return m && m.name ? m.name : "";
    }

    IpcHandler {
        target: "ryolayer"
        function toggle(mon: string): void { root.toggle(); }
        function show(mon: string): void { root.show(); }
        function hide(): void { root.hide(); }
    }

    // --- backdrop blur ------------------------------------------------------
    // Hyprland blur size is one global knob, so while the board is open we drive
    // it to Config.bgBlur and restore the read baseline on close. This carries
    // the launcher's proven pattern verbatim: writes serialize through a single
    // `hyprctl eval "hl.config(...)"` writer (a newer request replaces the
    // pending one and fires when the current exits, so states reach the
    // compositor in order), and the baseline is read only from a drained
    // compositor via getoption, restoring both enabled and size so a blur that
    // was off globally is put back off. At bgBlur = 0 the window takes the
    // "ryolayer-noblur" namespace instead and the compositor rule never matches.
    property bool blurForced: false
    property bool blurKnown: false
    property bool savedBlurEnabled: false
    property int savedBlurSize: 0
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
    function forceBackdropBlur() {
        root.blurForced = true;
        var want = Config.bgBlur | 0;
        root.evalBlur(want > 0, want);
    }
    function applyBackdropBlur() {
        if (Motion.blurDisabled || (Config.bgBlur | 0) <= 0)
            return;
        if (root.blurForced) {
            // already frosted: a live slider drag retunes the forced strength.
            root.forceBackdropBlur();
        } else {
            blurProbe.running = true;
        }
    }
    function restoreBlur() {
        if (!root.blurForced || !root.blurKnown)
            return;
        root.evalBlur(root.savedBlurEnabled, root.savedBlurSize);
        root.blurForced = false;
    }
    Timer {
        id: blurRestoreDelay
        interval: Motion.window
        onTriggered: root.restoreBlur()
    }
    onOpenChanged: {
        Quickshell.execDetached(["ryoku-shell", "state", "ryolayer", open ? "1" : "0"]);
        if (open) {
            blurRestoreDelay.stop();
            applyBackdropBlur();
        } else {
            blurRestoreDelay.restart();
        }
    }
    // a live slider drag while open retunes the forced strength.
    Connections {
        target: Config
        function onBgBlurChanged() {
            if (root.open)
                root.applyBackdropBlur();
        }
    }

    // --- the board, one per screen -----------------------------------------
    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property bool isFocused: !root.focusedName || root.focusedName === modelData.name
            readonly property bool shown: root.open

            screen: modelData
            visible: shown || closing.running
            color: "transparent"
            exclusiveZone: 0
            WlrLayershell.namespace: (Config.bgBlur | 0) > 0 && !Motion.blurDisabled ? "ryolayer" : "ryolayer-noblur"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: (shown && isFocused) ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            anchors { top: true; bottom: true; left: true; right: true }

            Grain { anchors.fill: parent; z: 10000; opacity: Tokens.grainOpacity }

            Timer { id: closing; interval: Motion.window; repeat: false }
            onShownChanged: if (!shown) closing.restart()

            Board {
                anchors.fill: parent
                screenName: win.modelData ? win.modelData.name : ""
                active: win.shown
                focusHere: win.isFocused
                onRequestClose: root.hide()

                opacity: win.shown ? 1 : 0
                scale: win.shown ? 1 : 0.97
                Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Motion.easeStandard } }
                Behavior on scale { NumberAnimation { duration: Motion.window; easing.type: Motion.easeExpo } }
            }
        }
    }
}
