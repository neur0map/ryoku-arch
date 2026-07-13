pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Webcam-overlay state, shared by the record-island toggle, the sidebar Mirror
// tile and CameraOverlay. The overlay is a shaped, draggable self-view bubble on
// a layer surface, so it stays across workspace switches and gsr captures it into
// recordings. Shape, size, flip and position persist to ~/.config/ryoku/camera.json;
// `active` stays in-memory so the camera starts off each session and is toggled
// on demand.
Singleton {
    id: root

    property bool active: false

    // shape (free-form; the resize handle writes bw/bh directly, logical px)
    readonly property real base: 220 // default edge
    readonly property real minEdge: 120 // smallest the resize handle allows
    property real bw: base
    property real bh: base
    property real roundness: 0.28 // 0 sharp corners .. 1 full circle/oval
    property bool flipped: true // horizontal mirror (selfie feel)

    // bubble top-left in global logical coordinates; NaN = unplaced (default
    // corner). NaN (not < 0) is the sentinel so legit negative coords on a
    // left/top monitor are never misread as unplaced.
    property real px: NaN
    property real py: NaN

    function toggle() {
        root.active = !root.active;
    }

    // ── persistence (shape/size/flip/position; never `active`) ────────────────
    readonly property string cfgPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/camera.json"
    property bool loaded: false

    function scheduleSave() {
        if (root.loaded)
            saveTimer.restart();
    }
    function save() {
        const j = JSON.stringify({
            bw: root.bw,
            bh: root.bh,
            roundness: root.roundness,
            flipped: root.flipped,
            px: root.px,
            py: root.py
        });
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname '" + root.cfgPath + "')\"; "
            + "printf '%s' '" + j + "' > '" + root.cfgPath + ".tmp'; "
            + "mv '" + root.cfgPath + ".tmp' '" + root.cfgPath + "'"]);
    }
    Timer { id: saveTimer; interval: 400; onTriggered: root.save() }

    onBwChanged: scheduleSave()
    onBhChanged: scheduleSave()
    onRoundnessChanged: scheduleSave()
    onFlippedChanged: scheduleSave()
    onPxChanged: scheduleSave()
    onPyChanged: scheduleSave()

    FileView {
        id: cfg
        path: root.cfgPath
        blockLoading: true
        watchChanges: false
        printErrors: false
        onLoaded: {
            try {
                const j = JSON.parse(cfg.text() || "{}");
                if (typeof j.bw === "number")
                    root.bw = j.bw;
                if (typeof j.bh === "number")
                    root.bh = j.bh;
                if (typeof j.roundness === "number")
                    root.roundness = j.roundness;
                if (typeof j.flipped === "boolean")
                    root.flipped = j.flipped;
                if (typeof j.px === "number")
                    root.px = j.px;
                if (typeof j.py === "number")
                    root.py = j.py;
            } catch (e) {}
            root.loaded = true;
        }
    }
}
