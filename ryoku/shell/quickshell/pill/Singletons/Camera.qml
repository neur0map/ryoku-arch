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

    // shape
    property string aspect: "square" // square | portrait | landscape
    property real roundness: 0.28 // 0 sharp corners .. 1 full circle/oval
    property real sizeScale: 1.0 // small 0.72 .. large 1.5
    property bool flipped: true // horizontal mirror (selfie feel)

    // bubble top-left in global logical coordinates; NaN = unplaced (default
    // corner). NaN (not < 0) is the sentinel so legit negative coords on a
    // left/top monitor are never misread as unplaced.
    property real px: NaN
    property real py: NaN

    // reference edge (px) at sizeScale 1.0
    readonly property real base: 220

    function toggle() {
        root.active = !root.active;
    }

    function cycleAspect() {
        root.aspect = root.aspect === "square" ? "portrait" : root.aspect === "portrait" ? "landscape" : "square";
    }

    function cycleSize() {
        root.sizeScale = root.sizeScale < 0.9 ? 1.0 : root.sizeScale < 1.2 ? 1.5 : 0.72;
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
            aspect: root.aspect,
            roundness: root.roundness,
            sizeScale: root.sizeScale,
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

    onAspectChanged: scheduleSave()
    onRoundnessChanged: scheduleSave()
    onSizeScaleChanged: scheduleSave()
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
                if (typeof j.aspect === "string")
                    root.aspect = j.aspect;
                if (typeof j.roundness === "number")
                    root.roundness = j.roundness;
                if (typeof j.sizeScale === "number")
                    root.sizeScale = j.sizeScale;
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
