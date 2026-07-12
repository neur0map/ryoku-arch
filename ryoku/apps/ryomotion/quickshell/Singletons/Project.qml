pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The edit session: one clip framed on a background, shaped by REGIONS on a
// timeline (zoom / cut / speed / text), plus the look, music and export knobs.
// Ported from openscreen's region model: a "cut" is a trim span to remove, a
// speed change is a span with a rate, a zoom is a span with a depth + focus.
// The panel binds to this; zoomAt() drives the live preview; Export serialises
// the whole thing to JSON for the `ryomotion` backend.
Singleton {
    id: project

    // ---- source ----
    property string clipPath: ""
    property string cursorPath: ""
    readonly property bool hasClip: clipPath !== ""
    property real durationMs: 0            // filled by the player once loaded
    property real positionMs: 0            // live playhead (player -> here)
    property bool playing: false

    // ---- canvas ----
    property string aspect: "auto"         // auto | 16:9 | 9:16 | 4:3 | 1:1
    readonly property var aspectRatios: ({ "16:9": 16 / 9, "9:16": 9 / 16, "4:3": 4 / 3, "1:1": 1, "auto": 0 })

    // ---- background + frame (the Beautify look, ported to video) ----
    property string bgKind: "gradient"     // gradient | solid | image
    property int bgPreset: 6
    property color bgSolid: "#20303f"
    property string bgImage: ""
    property real padding: 0.06            // fraction of the long edge
    property real roundness: 20            // px at native scale
    property real shadow: 0.35             // 0..1
    property real borderW: 0               // px
    property color borderColor: "#ffffff"

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

    // ---- zoom (openscreen depth scales + easing) ----
    property bool autoZoom: true            // derive regions from the cursor track
    property int zoomDepth: 3               // 1..6 -> 1.25x..5.0x (default for new regions)
    readonly property var depthScales: [1.25, 1.5, 1.8, 2.2, 3.5, 5.0]
    function depthScale(d) { return depthScales[Math.max(0, Math.min(5, (d || zoomDepth) - 1))]; }
    // openscreen transition windows + the Screen-Studio ease (cubic-bezier .16,1,.3,1).
    readonly property real zoomInMs: 1522.6
    readonly property real zoomOutMs: 1015.05

    // ---- cursor ----
    property bool showCursor: true
    property real cursorScale: 1.0          // 0.5 .. 3.0
    property real cursorSmooth: 0.35        // 0 .. 1 (follow smoothing)

    // ---- music (Ryoku addition over openscreen) ----
    property string musicPath: ""
    property real musicVolume: 0.6          // 0 .. 1

    // ---- export ----
    property string format: "mp4"          // mp4 | gif
    property string quality: "good"         // source | good | medium
    property int gifFps: 20                 // 15 | 20 | 25 | 30
    readonly property var qualityRes: ({ "source": 0, "good": 1080, "medium": 720 })
    property bool rendering: false
    property real renderProgress: 0         // 0..1
    property string lastExport: ""
    property bool recording: false

    // ================= REGIONS =================
    // Each region: { id, startMs, endMs, ...kind fields }. Arrays are reassigned
    // wholesale so bindings re-evaluate (QML doesn't watch in-place mutation).
    property var zoomRegions: []            // + depth, cx, cy, source ("manual"|"auto")
    property var trimRegions: []            // spans to REMOVE
    property var speedRegions: []           // + speed
    property var textRegions: []            // + text, x, y, size, color
    property var overlays: []               // + path, name, x, y, scale (clip-in-clip)
    property int _nextId: 1
    function _id() { return _nextId++; }

    // ---- selection (drives the rail panel + timeline highlight) ----
    property string tool: "canvas"          // canvas|frame|zoom|cut|speed|text|music|cursor|export
    property string selKind: ""             // "" | zoom | cut | speed | text
    property int selId: -1
    function selectRegion(kind, id) {
        selKind = kind;
        selId = id;
        if (kind === "cut") tool = "cut";
        else if (kind) tool = kind;
    }
    function clearSel() { selKind = ""; selId = -1; }
    function arrOf(kind) {
        return kind === "zoom" ? zoomRegions : kind === "cut" ? trimRegions
             : kind === "speed" ? speedRegions : kind === "text" ? textRegions
             : kind === "overlay" ? overlays : [];
    }
    function selected() {
        if (selKind === "" || selId < 0) return null;
        var a = arrOf(selKind);
        for (var i = 0; i < a.length; i++) if (a[i].id === selId) return a[i];
        return null;
    }

    // default span at the playhead: 5% of the clip, clamped 1..30s, non-overlapping.
    function _span(existing) {
        var dur = Math.max(1000, Math.min(30000, durationMs * 0.05 || 3000));
        var s = positionMs;
        var e = Math.min(durationMs || s + dur, s + dur);
        // shrink to the next region's start so hard tracks never overlap
        for (var i = 0; i < existing.length; i++)
            if (existing[i].startMs > s && existing[i].startMs < e) e = existing[i].startMs;
        return { s: s, e: Math.max(s + 200, e) };
    }
    function _sortByStart(a) { return a.slice().sort(function (x, y) { return x.startMs - y.startMs; }); }
    function _blocked(existing, s) {
        for (var i = 0; i < existing.length; i++)
            if (s >= existing[i].startMs && s < existing[i].endMs) return true;
        return false;
    }

    function addZoom() {
        if (!hasClip || _blocked(zoomRegions, positionMs)) return;
        var sp = _span(zoomRegions);
        var r = { id: _id(), startMs: sp.s, endMs: sp.e, depth: zoomDepth, cx: 0.5, cy: 0.5, source: "manual" };
        zoomRegions = _sortByStart(zoomRegions.concat([r]));
        selectRegion("zoom", r.id);
    }
    function addCut() {
        if (!hasClip || _blocked(trimRegions, positionMs)) return;
        var sp = _span(trimRegions);
        var r = { id: _id(), startMs: sp.s, endMs: sp.e };
        trimRegions = _sortByStart(trimRegions.concat([r]));
        selectRegion("cut", r.id);
    }
    function addSpeed() {
        if (!hasClip || _blocked(speedRegions, positionMs)) return;
        var sp = _span(speedRegions);
        var r = { id: _id(), startMs: sp.s, endMs: sp.e, speed: 2.0 };
        speedRegions = _sortByStart(speedRegions.concat([r]));
        selectRegion("speed", r.id);
    }
    function addText() {
        if (!hasClip) return;
        var sp = _span([]);
        var r = { id: _id(), startMs: sp.s, endMs: sp.e, text: "Text", x: 0.5, y: 0.18, size: 0.06, color: "#ffffff" };
        textRegions = _sortByStart(textRegions.concat([r]));
        selectRegion("text", r.id);
    }
    function addOverlay(path) {
        if (!hasClip || !path) return;
        var sp = _span([]);
        var r = { id: _id(), path: path, name: path.split("/").pop(), startMs: sp.s, endMs: sp.e, x: 0.72, y: 0.72, scale: 0.34 };
        overlays = _sortByStart(overlays.concat([r]));
        selectRegion("overlay", r.id);
    }
    function removeRegion(kind, id) {
        _writeArr(kind, arrOf(kind).filter(function (r) { return r.id !== id; }));
        if (selKind === kind && selId === id) clearSel();
    }
    function updateRegion(kind, id, patch) {
        var a = arrOf(kind).slice();
        for (var i = 0; i < a.length; i++)
            if (a[i].id === id) { a[i] = Object.assign({}, a[i], patch); break; }
        _writeArr(kind, a);
    }
    function _writeArr(kind, a) {
        if (kind === "zoom") zoomRegions = a;
        else if (kind === "cut") trimRegions = a;
        else if (kind === "speed") speedRegions = a;
        else if (kind === "text") textRegions = a;
        else if (kind === "overlay") overlays = a;
    }
    function updateSel(patch) { if (selKind && selId >= 0) updateRegion(selKind, selId, patch); }

    // ---- the LIVE zoom transform at a playhead (must mirror the render) ----
    // cubic-bezier(0.16, 1, 0.3, 1) ~= a strong ease-out; we sample it by t.
    function _ease(t) {
        t = Math.max(0, Math.min(1, t));
        return 1 - Math.pow(1 - t, 3);      // easeOutCubic (close to the SS bezier)
    }
    // returns { scale, cx, cy } for the currently active zoom region (regions
    // don't overlap, so at most one contributes, including its in/out ramps).
    function zoomAt(ms) {
        for (var i = 0; i < zoomRegions.length; i++) {
            var r = zoomRegions[i];
            if (ms < r.startMs || ms > r.endMs) continue;
            var inW = Math.min(zoomInMs, (r.endMs - r.startMs) / 2);
            var outW = Math.min(zoomOutMs, (r.endMs - r.startMs) / 2);
            var prog = 1;
            if (ms < r.startMs + inW) prog = _ease((ms - r.startMs) / inW);
            else if (ms > r.endMs - outW) prog = _ease((r.endMs - ms) / outW);
            var sc = 1 + (depthScale(r.depth) - 1) * prog;
            return { scale: sc, cx: r.cx, cy: r.cy };
        }
        return { scale: 1, cx: 0.5, cy: 0.5 };
    }
    // the text regions visible at a playhead (for the live overlay).
    function textsAt(ms) {
        return textRegions.filter(function (r) { return ms >= r.startMs && ms <= r.endMs; });
    }
    // the overlays (clip-in-clip) active at a playhead.
    function overlaysAt(ms) {
        return overlays.filter(function (r) { return ms >= r.startMs && ms <= r.endMs; });
    }

    readonly property string projTmp: "/tmp/ryomotion-project.json"
    function projectsDir() { return (Quickshell.env("HOME") || "") + "/Videos/Ryoku Motion"; }

    function openClip(path) {
        if (!path) return;
        clipPath = path;
        var base = path.replace(/\.[^.]+$/, "");
        cursorPath = base + ".cursor";
        positionMs = 0;
        zoomRegions = []; trimRegions = []; speedRegions = []; textRegions = []; overlays = [];
        clearSel();
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
            aspect: aspect,
            bg: { kind: bgKind, a: "" + bgA, b: "" + bgB, angle: bgAngle, solid: "" + bgSolid, image: bgImage },
            padding: padding, roundness: roundness, shadow: shadow,
            border: { w: borderW, color: "" + borderColor },
            cursor_opts: { show: showCursor, scale: cursorScale, smooth: cursorSmooth },
            music: { path: musicPath, volume: musicVolume },
            zoom: { auto: autoZoom, depth: zoomDepth, regions: zoomRegions.map(function (r) {
                return { start: r.startMs / 1000, end: r.endMs / 1000, scale: depthScale(r.depth), cx: r.cx, cy: r.cy };
            }) },
            trims: trimRegions.map(function (r) { return { start: r.startMs / 1000, end: r.endMs / 1000 }; }),
            speeds: speedRegions.map(function (r) { return { start: r.startMs / 1000, end: r.endMs / 1000, speed: r.speed }; }),
            texts: textRegions.map(function (r) {
                return { start: r.startMs / 1000, end: r.endMs / 1000, text: r.text, x: r.x, y: r.y, size: r.size, color: "" + r.color };
            }),
            overlays: overlays.map(function (r) {
                return { path: r.path, start: r.startMs / 1000, end: r.endMs / 1000, x: r.x, y: r.y, scale: r.scale };
            }),
            fps: fmt === "gif" ? gifFps : 60,
            quality: quality,
            format: fmt
        });
    }

    function exportVideo(fmt) {
        if (!hasClip || rendering) return;
        format = fmt;
        rendering = true;
        renderProgress = 0;
        var out = projectsDir() + "/export_" + Date.now() + "." + fmt;
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
            project.renderProgress = code === 0 ? 1 : 0;
            if (code === 0) project.lastExport = renderProc._out;
        }
    }

    // ---- record: hand off to the backend, then poll until it stops ----
    function record(region) {
        if (recording) return;
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
            if (recordProc._proj !== "") openTimer.restart();
        }
    }
    Timer {
        id: openTimer
        interval: 700
        onTriggered: {
            openProj.command = ["sh", "-c", "jq -r '.clip' \"$1\"", "sh", recordProc._proj];
            openProj.running = true;
        }
    }
    Process {
        id: openProj
        stdout: StdioCollector { onStreamFinished: { var c = this.text.trim(); if (c) project.openClip(c); } }
    }
}
