pragma Singleton
import QtQuick

// The edit session: the clip plus regions (zoom / speed / text / overlay) and
// cuts (spans removed from the result), the look/cursor/music/export knobs, and
// the project JSON the backend turns into the live preview graph + the export.
// Backend I/O (probe/graph/render/record) is wired from Main.qml.
QtObject {
    id: project

    // ---- source ----
    property string clipPath: ""
    property url clipUrl: ""
    readonly property bool hasClip: clipPath !== ""
    property real durationMs: 0
    property real positionMs: 0
    property bool playing: false
    property bool hasCursor: false

    // ---- transport (UI drives these; Stage owns the actual player) ----
    signal playRequested()
    signal pauseRequested()
    signal seekRequested(real ms)
    function play() { if (hasClip) playRequested() }
    function pause() { pauseRequested() }
    function togglePlay() { if (!hasClip) return; playing ? pauseRequested() : playRequested() }
    function seek(ms) { positionMs = Math.max(0, Math.min(durationMs, ms)); seekRequested(positionMs) }
    signal chooseMusicRequested()   // UI asks Main to open the shared audio picker

    // ---- canvas ----
    property string aspect: "auto"
    readonly property var aspectRatios: ({ "16:9": 16 / 9, "9:16": 9 / 16, "4:3": 4 / 3, "1:1": 1, "auto": 0 })

    // ---- background + frame (Beautify look) ----
    property string bgKind: "gradient"
    property int bgPreset: 6
    property color bgSolid: "#20303f"
    property string bgImage: ""
    property real padding: 0.06
    property real roundness: 20
    property real shadow: 0.35
    property real borderW: 0
    property color borderColor: "#ffffff"

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

    // ---- zoom ----
    property bool autoZoom: true
    property int zoomDepth: 3
    readonly property var depthScales: [1.25, 1.5, 1.8, 2.2, 3.5, 5.0]
    function depthScale(d) { return depthScales[Math.max(0, Math.min(5, (d || zoomDepth) - 1))]; }

    // ---- music / export ----
    property string musicPath: ""
    property real musicVolume: 0.6
    property string format: "mp4"
    property string quality: "good"
    property int gifFps: 20
    property bool rendering: false
    property string lastExport: ""

    // ---- regions ----
    property var zooms: []
    property var speeds: []
    property var texts: []
    property var overlays: []
    property var cuts: []               // spans removed from the result (gaps)
    property int _nextId: 1
    function _id() { return _nextId++; }

    // selection range on the clip (for direct cut), ms; -1 = none
    property real selStart: -1
    property real selEnd: -1

    // ---- rail + region selection ----
    property string tool: "canvas"
    property string selKind: ""
    property int selId: -1
    signal dirty()                       // structural change -> preview graph refresh

    function arrOf(kind) {
        return kind === "zoom" ? zooms : kind === "speed" ? speeds
             : kind === "text" ? texts : kind === "overlay" ? overlays
             : kind === "cut" ? cuts : [];
    }
    function _write(kind, a) {
        if (kind === "zoom") zooms = a;
        else if (kind === "speed") speeds = a;
        else if (kind === "text") texts = a;
        else if (kind === "overlay") overlays = a;
        else if (kind === "cut") cuts = a;
        dirty();
    }
    function selectRegion(kind, id) { selKind = kind; selId = id; if (kind) tool = kind; }
    function clearSel() { selKind = ""; selId = -1; }
    function selected() {
        if (!selKind || selId < 0) return null;
        var a = arrOf(selKind);
        for (var i = 0; i < a.length; i++) if (a[i].id === selId) return a[i];
        return null;
    }
    function _sort(a) { return a.slice().sort(function (x, y) { return x.startMs - y.startMs; }); }
    function _span() {
        var dur = Math.max(1000, Math.min(30000, durationMs * 0.05 || 3000));
        return { s: positionMs, e: Math.min(durationMs || positionMs + dur, positionMs + dur) };
    }
    function addZoom() {
        if (!hasClip) return;
        var sp = _span();
        var r = { id: _id(), startMs: sp.s, endMs: sp.e, depth: zoomDepth, cx: 0.5, cy: 0.5 };
        zooms = _sort(zooms.concat([r])); selectRegion("zoom", r.id); dirty();
    }
    function addSpeed() {
        if (!hasClip) return;
        var sp = _span();
        var r = { id: _id(), startMs: sp.s, endMs: sp.e, speed: 2.0 };
        speeds = _sort(speeds.concat([r])); selectRegion("speed", r.id); dirty();
    }
    function addText() {
        if (!hasClip) return;
        var sp = _span();
        var r = { id: _id(), startMs: sp.s, endMs: sp.e, text: "Text", x: 0.5, y: 0.15, size: 0.06, color: "#ffffff" };
        texts = _sort(texts.concat([r])); selectRegion("text", r.id); dirty();
    }
    function addOverlay(path) {
        if (!hasClip || !path) return;
        var sp = _span();
        var r = { id: _id(), path: path, name: ("" + path).split("/").pop(), startMs: sp.s, endMs: sp.e, x: 0.72, y: 0.72, scale: 0.34 };
        overlays = _sort(overlays.concat([r])); selectRegion("overlay", r.id); dirty();
    }
    function removeRegion(kind, id) {
        _write(kind, arrOf(kind).filter(function (r) { return r.id !== id; }));
        if (selKind === kind && selId === id) clearSel();
    }
    function updateRegion(kind, id, patch) {
        var a = arrOf(kind).slice();
        for (var i = 0; i < a.length; i++) if (a[i].id === id) { a[i] = Object.assign({}, a[i], patch); break; }
        _write(kind, a);
    }
    function updateSel(patch) { if (selKind && selId >= 0) updateRegion(selKind, selId, patch); }

    // ---- direct cut: remove the selected span (shows as a gap) ----
    function removeSelection() {
        if (selStart < 0 || selEnd <= selStart) return;
        var r = { id: _id(), startMs: selStart, endMs: selEnd };
        cuts = _sort(cuts.concat([r]));
        selStart = -1; selEnd = -1;
        dirty();
    }
    // speed at a playhead (for live playback rate); 1 if none.
    function speedAt(ms) {
        for (var i = 0; i < speeds.length; i++) if (ms >= speeds[i].startMs && ms < speeds[i].endMs) return speeds[i].speed;
        return 1;
    }
    // the cut covering ms, or null (for seek-skip during preview playback).
    function cutAt(ms) {
        for (var i = 0; i < cuts.length; i++) if (ms >= cuts[i].startMs && ms < cuts[i].endMs) return cuts[i];
        return null;
    }

    // ---- live zoom transform at a playhead (mirrors the ffmpeg crop-zoom) ----
    readonly property real zoomInMs: 1522.6
    readonly property real zoomOutMs: 1015.05
    function _ease(t) { t = Math.max(0, Math.min(1, t)); return t * t * t * (t * (t * 6 - 15) + 10); }  // smootherstep, matches export
    // returns { scale, cx, cy } for the active zoom region (regions don't overlap).
    function zoomAt(ms) {
        for (var i = 0; i < zooms.length; i++) {
            var r = zooms[i];
            if (ms < r.startMs || ms > r.endMs) continue;
            var inW = Math.min(zoomInMs, (r.endMs - r.startMs) / 2);
            var outW = Math.min(zoomOutMs, (r.endMs - r.startMs) / 2);
            var prog = 1;
            if (ms < r.startMs + inW) prog = _ease((ms - r.startMs) / inW);
            else if (ms > r.endMs - outW) prog = _ease((r.endMs - ms) / outW);
            return { scale: 1 + (depthScale(r.depth) - 1) * prog, cx: r.cx, cy: r.cy };
        }
        return { scale: 1, cx: 0.5, cy: 0.5 };
    }
    function textsAt(ms) {
        return texts.filter(function (r) { return ms >= r.startMs && ms <= r.endMs; });
    }

    function projectsDir() { return ""; }   // filled by Backend.videosDir() in Main

    function openClip(url) {
        var p = ("" + url).replace(/^file:\/\//, "");
        if (!p) return;
        clipUrl = url; clipPath = p;
        positionMs = 0;
        zooms = []; speeds = []; texts = []; overlays = []; cuts = [];
        selStart = -1; selEnd = -1; clearSel();
        dirty();
    }

    function projectJson(fmt) {
        return JSON.stringify({
            clip: clipPath,
            cursor: hasCursor ? clipPath.replace(/\.[^.]+$/, "") + ".cursor" : "",
            aspect: aspect,
            bg: { kind: bgKind, a: "" + bgA, b: "" + bgB, angle: bgAngle, solid: "" + bgSolid, image: bgImage },
            padding: padding, roundness: roundness, shadow: shadow,
            border: { w: borderW, color: "" + borderColor },
            music: { path: musicPath, volume: musicVolume },
            zoom: { auto: autoZoom, depth: zoomDepth, regions: zooms.map(function (r) {
                return { start: r.startMs / 1000, end: r.endMs / 1000, scale: depthScale(r.depth), cx: r.cx, cy: r.cy };
            }) },
            trims: cuts.map(function (r) { return { start: r.startMs / 1000, end: r.endMs / 1000 }; }),
            speeds: speeds.map(function (r) { return { start: r.startMs / 1000, end: r.endMs / 1000, speed: r.speed }; }),
            texts: texts.map(function (r) {
                return { start: r.startMs / 1000, end: r.endMs / 1000, text: r.text, x: r.x, y: r.y, size: r.size, color: "" + r.color };
            }),
            overlays: overlays.map(function (r) {
                return { path: r.path, start: r.startMs / 1000, end: r.endMs / 1000, x: r.x, y: r.y, scale: r.scale };
            }),
            fps: fmt === "gif" ? gifFps : 60,
            quality: quality, format: fmt
        });
    }
}
