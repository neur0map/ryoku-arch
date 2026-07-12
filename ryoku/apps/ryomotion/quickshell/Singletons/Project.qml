pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The edit session: the clip being framed + all the look/zoom/export knobs, plus
// the glue to the `ryomotion` backend (record, and write-project-then-render).
// One document; the panel binds to it and Export serialises it to JSON.
Singleton {
    id: project

    // ---- source ----
    property string clipPath: ""
    property string cursorPath: ""
    readonly property bool hasClip: clipPath !== ""
    property real durationMs: 0            // filled by the player once loaded
    property real positionMs: 0            // live playhead (player -> here)

    // ---- edit ----
    property real trimStartMs: 0
    property real trimEndMs: 0             // 0 = to end
    property real speed: 1.0

    // ---- frame (the Beautify look, ported to video) ----
    property string bgKind: "gradient"     // gradient | solid | image
    property int bgPreset: 0
    property color bgSolid: "#20303f"
    property string bgImage: ""
    property real padding: 0.06            // fraction of the long edge
    property real roundness: 20            // px at native scale
    property real shadow: 0.35             // 0..1

    // ---- zoom (openscreen-ported) ----
    property bool zoomEnabled: true
    property int zoomDepth: 3               // 1..6 -> 1.25x..5.0x
    readonly property var depthScales: [1.25, 1.5, 1.8, 2.2, 3.5, 5.0]
    readonly property real depthScale: depthScales[Math.max(0, Math.min(5, zoomDepth - 1))]

    // ---- export ----
    property int fps: 60
    property string format: "mp4"          // mp4 | gif
    property bool rendering: false
    property string lastExport: ""
    property bool recording: false

    // curated gradient presets (shared with ryowalls/Beautify).
    readonly property var presets: [
        { "a": "#4facfe", "b": "#00c6a7", "ang": 135 },
        { "a": "#f6543e", "b": "#f7b733", "ang": 135 },
        { "a": "#7b4397", "b": "#dc2430", "ang": 135 },
        { "a": "#11998e", "b": "#38ef7d", "ang": 135 },
        { "a": "#ee9ca7", "b": "#ffdde1", "ang": 135 },
        { "a": "#334155", "b": "#0f172a", "ang": 135 },
        { "a": "#e2342a", "b": "#14120f", "ang": 135 },
        { "a": "#00c3ff", "b": "#ffff1c", "ang": 135 },
        { "a": "#ffecd2", "b": "#fcb69f", "ang": 135 },
        { "a": "#3e6868", "b": "#0f1514", "ang": 135 }
    ]
    readonly property color bgA: presets[Math.max(0, Math.min(presets.length - 1, bgPreset))].a
    readonly property color bgB: presets[Math.max(0, Math.min(presets.length - 1, bgPreset))].b
    readonly property real bgAngle: presets[Math.max(0, Math.min(presets.length - 1, bgPreset))].ang

    readonly property string projTmp: "/tmp/ryomotion-project.json"
    function projectsDir() { return (Quickshell.env("HOME") || "") + "/Videos/Ryoku Motion"; }

    function openClip(path) {
        if (!path)
            return;
        clipPath = path;
        // a ryomotion recording drops a <base>.cursor beside the mp4.
        var base = path.replace(/\.[^.]+$/, "");
        cursorPath = base + ".cursor";
        trimStartMs = 0;
        trimEndMs = 0;
        positionMs = 0;
        cursorProbe.command = ["sh", "-c", "[ -r \"$1\" ] && echo yes || echo no", "sh", cursorPath];
        cursorProbe.running = true;
    }

    // cursor track only exists for clips recorded through ryomotion.
    property bool hasCursor: false
    Process {
        id: cursorProbe
        stdout: StdioCollector { onStreamFinished: project.hasCursor = (this.text.trim() === "yes") }
    }

    function projectJson(fmt) {
        return JSON.stringify({
            clip: clipPath,
            cursor: hasCursor ? cursorPath : "",
            trimStart: trimStartMs / 1000,
            trimEnd: trimEndMs / 1000,
            speed: speed,
            bg: {
                kind: bgKind,
                a: "" + bgA, b: "" + bgB, angle: bgAngle,
                solid: "" + bgSolid, image: bgImage
            },
            padding: padding,
            roundness: roundness,
            shadow: shadow,
            zoom: { enabled: zoomEnabled, depth: zoomDepth, regions: [] },
            fps: fps,
            format: fmt
        });
    }

    function exportVideo(fmt) {
        if (!hasClip || rendering)
            return;
        format = fmt;
        rendering = true;
        var out = projectsDir() + "/export_" + Date.now() + "." + fmt;
        // write the project, then render it, in one shot.
        renderProc.command = ["sh", "-c",
            "mkdir -p \"$(dirname \"$3\")\"; printf %s \"$1\" > \"$2\"; exec ryomotion render \"$2\" \"$3\"",
            "sh", projectJson(fmt), projTmp, out];
        renderProc._out = out;
        renderProc.running = true;
    }
    Process {
        id: renderProc
        property string _out: ""
        onExited: (code, status) => {
            project.rendering = false;
            if (code === 0)
                project.lastExport = renderProc._out;
        }
    }

    // ---- record: hand off to the backend, then poll until it stops ----
    function record(region) {
        if (recording)
            return;
        recordProc.command = region ? ["ryomotion", "record", "--region"] : ["ryomotion", "record"];
        recordProc.running = true;
    }
    function stopRecord() {
        stopProc.command = ["ryomotion", "stop"];
        stopProc.running = true;
    }
    Process {
        id: recordProc
        property string _proj: ""
        stdout: StdioCollector { onStreamFinished: recordProc._proj = this.text.trim() }
        onStarted: project.recording = true
    }
    Process {
        id: stopProc
        onExited: (code, status) => {
            project.recording = false;
            if (recordProc._proj !== "")
                openTimer.restart();
        }
    }
    // give gsr a beat to flush the muxer before we load the clip.
    Timer {
        id: openTimer
        interval: 700
        onTriggered: {
            var p = openProj.command = ["sh", "-c", "jq -r '.clip' \"$1\"", "sh", recordProc._proj];
            openProj.running = true;
        }
    }
    Process {
        id: openProj
        stdout: StdioCollector { onStreamFinished: { var c = this.text.trim(); if (c) project.openClip(c); } }
    }
}
