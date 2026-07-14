pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "Singletons"

// desktop spectrum. full-width cava analyser in seven looks: bars, floating
// dots, a stiff angular line, a filled wave, lit segments, and two polar looks,
// a radial ring of bars and a morphing circle whose radius is the amplitude.
// bars/dots/line/wave/segments anchor bottom/top/centre; radial and circle sit
// at screen centre. each band = a wallust colour so the sweep retunes with the
// wallpaper. soft bloom behind, fading reflection under bottom bars, optional
// falling peak caps.
//
// motion = a Timer at Config.fps (cava feeds the same rate), halved when idle,
// OFF when silent. decoupled from vsync so a 165Hz panel doesn't redraw for
// nothing. per-band ease (fast attack, slow decay) plus an `activity` signal
// cross-fades live spectrum <-> calm idle wave. the adaptive governor watches
// the ticker's slip and steps cost down under load, shedding the blur buffer,
// reflection and peaks and folding segments back to bars, without ever
// stopping the draw.
Item {
    id: root

    readonly property int bands: Spectrum.bars
    readonly property real ui: Math.max(0.75, height / 1080)

    // unknown values (an old style dropped from the set) fall back to bars so a
    // stale config never renders blank.
    readonly property var knownStyles: ["bars", "dots", "line", "wave", "segments", "radial", "circle"]
    readonly property string style: root.knownStyles.indexOf(Config.style) >= 0 ? Config.style : "bars"
    readonly property string position: Config.position
    readonly property bool mirror: Config.mirror

    // --- adaptive governor --------------------------------------------------
    // the render Timer's overrun (asked interval vs measured) is a cheap,
    // portable proxy for "this machine can't keep up". we climb tiers with
    // hysteresis and a dwell, shedding effects on the way up; effStyle drops
    // the priciest style a notch so a heavy pick still costs little under load.
    property real govOverrun: 1
    property int govTier: 0
    property real govSince: 0
    readonly property bool govOn: Config.adaptive
    readonly property string effStyle: (root.govOn && root.govTier >= 2 && root.style === "segments") ? "bars" : root.style
    readonly property int effFps: {
        if (!root.govOn || root.govTier === 0)
            return Config.fps;
        return root.govTier === 1 ? Math.min(Config.fps, 30) : Math.min(Config.fps, 24);
    }
    readonly property real effBloom: {
        if (!root.govOn || root.govTier === 0)
            return Config.bloom;
        return root.govTier === 1 ? Config.bloom * 0.5 : 0;
    }
    readonly property bool wantPeaks: Config.peaks && root.position !== "center"
        && (root.effStyle === "bars" || root.effStyle === "segments")
        && !(root.govOn && root.govTier >= 2)

    readonly property bool polar: root.effStyle === "radial" || root.effStyle === "circle"
    readonly property bool reflects: root.effStyle === "bars" && root.position === "bottom"
        && Config.reflection > 0 && !(root.govOn && root.govTier >= 2)
    readonly property real reflectionH: root.reflects ? Math.round(height * Config.reflection) : 0
    readonly property real maxBarH: Math.round(height * Config.height)
    readonly property real baseBottom: height - reflectionH
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real slotW: bands > 0 ? width / bands : width
    readonly property real barW: Math.max(2, slotW * Config.thickness)
    readonly property real capR: Config.shape === "rounded" ? root.barW / 2 : Math.min(3 * root.ui, root.barW * 0.2)

    readonly property int segN: Math.max(4, Math.min(16, Config.segments))
    readonly property real segGap: Math.max(1.5 * root.ui, root.maxBarH / root.segN * 0.26)

    // polar geometry: an inner ring the radial bars grow from and the circle
    // wobbles around, both scaled to the shorter screen edge so they stay round.
    readonly property real ringR0: Math.min(width, height) * (0.10 + 0.06 * Config.height)
    readonly property real ringMax: Math.min(width, height) * (0.10 + 0.22 * Config.height)
    readonly property real radialArcW: Math.max(2, (2 * Math.PI * root.ringR0 / Math.max(1, bands)) * Config.thickness)

    readonly property bool areaStyle: root.effStyle === "wave"

    // --- motion engine ------------------------------------------------------
    // smoothed per-band heights (0..1), falling peak holds, and a 0..1 "is
    // music playing" signal. everything eases per frame, nothing jumps.
    property var levels: []
    property var peaks: []
    property real activity: 0
    property real idlePhase: 0
    property real maxLevel: 0
    property bool waveOn: false
    property string fillPath: ""
    property string linePath: ""
    property string circlePath: ""
    readonly property bool sounding: Spectrum.energy > 0.04 || root.activity > 0.02
    // the idle wave breathes only while sound is actually present, and freezes
    // (clears) on real silence, keyed off measured energy, not merely an
    // uncorked stream. a silent-but-open stream (Discord in a call, a browser
    // tab holding an audio context) otherwise defeats the freeze and leaves
    // idle lines breathing on a silent desktop. freezing also spares this
    // Qt/NVIDIA stack the idle animation, which leaks there.
    readonly property bool idleFrozen: Performance.visualizerFrozen && !root.sounding
    readonly property bool wantIdleWave: Config.idleWave && !root.idleFrozen
    // anything to animate at all? silent, settled, and no wave -> ticker stops.
    readonly property bool animating: root.sounding || root.wantIdleWave || root.maxLevel > 0.004

    function srcIndex(i) {
        if (!root.mirror)
            return i;
        var c = Math.floor(root.bands / 2);
        return Math.max(0, Math.min(root.bands - 1, Math.abs(i - c)));
    }
    function rawLevel(i) {
        var l = Spectrum.levels;
        var s = root.srcIndex(i);
        var v = (l && s < l.length) ? l[s] : 0;
        return Math.min(1, Math.pow(v, 0.72) * Config.gain);
    }
    function idleLevel(i) {
        return 0.012 + 0.02 * (0.5 + 0.5 * Math.sin(root.srcIndex(i) * 0.4 + root.idlePhase));
    }
    function levelAt(i) {
        var dl = root.levels;
        return (dl && i < dl.length) ? dl[i] : 0;
    }

    Timer {
        id: ticker
        // a background effect that is software-rendered on hybrid GPUs
        // (transparency rules out the GPU), so it rides Config.fps rather than
        // vsync: sounding at the ceiling, idle at half. the governor lowers the
        // ceiling under load.
        interval: Math.round(1000 / (root.sounding ? root.effFps : Math.max(20, root.effFps / 2)))
        running: root.visible && Config.enabled && root.animating
        repeat: true
        property real last: 0
        onTriggered: {
            var now = Date.now();
            var raw = last > 0 ? (now - last) / 1000 : interval / 1000;
            last = now;
            if (root.govOn)
                root.governor(raw, interval / 1000);
            root.tick(Math.min(0.05, raw));
        }
    }

    // climb/descend tiers on a slow EMA of overrun, with a dwell so a single
    // hitch never trips a change and the tier doesn't oscillate.
    function governor(raw, asked) {
        var ratio = Math.min(3, asked > 0 ? raw / asked : 1);
        root.govOverrun += (ratio - root.govOverrun) * 0.1;
        var now = Date.now();
        if (now - root.govSince < 2500)
            return;
        if (root.govOverrun > 1.6 && root.govTier < 2) {
            root.govTier += 1;
            root.govSince = now;
            root.shed();
        } else if (root.govOverrun < 1.15 && root.govTier > 0) {
            root.govTier -= 1;
            root.govSince = now;
        }
    }
    // drop the paths and peak array the new tier no longer paints so their
    // buffers can be reclaimed.
    function shed() {
        if (!root.areaStyle)
            root.fillPath = "";
        if (root.effStyle !== "line")
            root.linePath = "";
        if (root.effStyle !== "circle")
            root.circlePath = "";
        if (!root.wantPeaks && root.peaks.length)
            root.peaks = [];
    }

    function tick(dt) {
        // activity: fast rise on sound start, slow release so short gaps
        // don't flicker the spectrum off.
        var goal = Spectrum.energy > 0.04 ? 1 : 0;
        var aK = 1 - Math.exp(-dt / (goal > root.activity ? 0.05 : 1.1));
        root.activity += (goal - root.activity) * aK;
        if (root.wantIdleWave)
            root.idlePhase += dt * (Math.PI * 2 / 6);

        var n = root.bands;
        var prev = root.levels;
        var idleAmt = root.wantIdleWave ? (1 - root.activity) : 0;
        // smoothing stretches the decay (and a touch of the attack); the
        // default matches the old fixed feel.
        var decay = 0.06 + 0.20 * Config.smoothing;
        var attack = 0.035 + 0.02 * Config.smoothing;
        // the line is a stiff readout: snap up hard, fall fast, so its motion
        // stays staccato where the wave flows.
        if (root.effStyle === "line") {
            decay *= 0.5;
            attack *= 0.55;
        }
        var out = new Array(n);
        for (var i = 0; i < n; i++) {
            var target = root.activity * root.rawLevel(i) + idleAmt * root.idleLevel(i);
            var cur = (prev && i < prev.length) ? prev[i] : 0;
            var k = 1 - Math.exp(-dt / (target > cur ? attack : decay));
            out[i] = cur + (target - cur) * k;
        }
        root.levels = out;

        var mx = 0;
        for (var j = 0; j < n; j++)
            if (out[j] > mx)
                mx = out[j];
        root.maxLevel = mx;

        if (root.wantPeaks) {
            var pk = root.peaks;
            var np = new Array(n);
            for (var p = 0; p < n; p++) {
                var pc = (pk && p < pk.length) ? pk[p] - dt * 0.5 : 0;
                np[p] = out[p] > pc ? out[p] : Math.max(0, pc);
            }
            root.peaks = np;
        } else if (root.peaks.length) {
            root.peaks = [];
        }

        var draw = root.wantIdleWave || mx > 0.003;
        if (root.areaStyle) {
            if (draw || root.waveOn) {
                root.fillPath = root.buildFillPath();
                root.waveOn = draw;
            }
        } else if (root.fillPath !== "") {
            root.fillPath = "";
        }
        if (root.effStyle === "line")
            root.linePath = draw ? root.buildAnglePath() : "";
        else if (root.linePath !== "")
            root.linePath = "";
        if (root.effStyle === "circle")
            root.circlePath = draw ? root.buildCirclePath() : "";
        else if (root.circlePath !== "")
            root.circlePath = "";
    }

    function bandColor(i) {
        return Wallust.colorAt(root.bands > 1 ? i / (root.bands - 1) : 0.5);
    }
    function lengthAt(i) {
        // min sliver fades with the spectrum when idle wave is off, so a
        // silent desktop clears fully instead of leaving a thin line.
        var minH = 2 * root.ui * (root.wantIdleWave ? 1 : root.activity);
        return Math.max(minH, root.maxBarH * root.levelAt(i));
    }
    function barY(len) {
        if (root.position === "top")
            return 0;
        if (root.position === "center")
            return root.cy - len / 2;
        return root.baseBottom - len;
    }
    function tipY(len) {
        if (root.position === "top")
            return len;
        if (root.position === "center")
            return root.cy - len / 2;
        return root.baseBottom - len;
    }

    // floor glow under bottom spectra. warms with overall energy.
    Rectangle {
        visible: root.position === "bottom" && !root.polar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.maxBarH * 0.7
        opacity: (root.wantIdleWave ? 0.08 : 0) + 0.34 * root.activity
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(Wallust.accent, 0.5) }
        }
    }

    // bloom = blurred copy of the crisp field sitting just behind it. the blur
    // pass runs every visible frame and is ruinous without GPU acceleration, so
    // it is disabled outright whenever bloom is off (config or governor) or the
    // field is flat, which also frees its offscreen buffer.
    MultiEffect {
        source: field
        anchors.fill: field
        z: 0
        visible: !Performance.blurDisabled && root.effBloom > 0 && root.maxLevel > 0.01
        blurEnabled: !Performance.blurDisabled && root.effBloom > 0 && root.maxLevel > 0.01
        blur: 1.0
        blurMax: 24
        autoPaddingEnabled: true
        opacity: root.effBloom * (0.5 + 0.5 * root.activity)
    }

    // reflection: bottom bars mirrored below the baseline, each fading down.
    Item {
        x: 0
        y: root.baseBottom
        width: root.width
        height: root.reflectionH
        opacity: 0.45
        visible: root.reflects

        Repeater {
            model: root.reflects ? root.bands : 0
            Rectangle {
                required property int index
                readonly property color c: root.bandColor(index)
                width: root.barW
                x: index * root.slotW + (root.slotW - root.barW) / 2
                y: 0
                height: Math.min(root.reflectionH, root.lengthAt(index) * 0.5)
                radius: root.capR
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(c, 0.32) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    // the field = active style, drawn crisp.
    Item {
        id: field
        anchors.fill: parent
        z: 1
        // with the idle wave off, fade out as the "music playing" signal
        // releases, so styles with a fixed baseline (the circle ring, the
        // radial centre) vanish on silence instead of freezing when the ticker
        // halts. the floor meets the ticker's stop threshold, so it reads 0
        // exactly when motion stops.
        opacity: root.wantIdleWave ? 1 : Math.max(0, Math.min(1, (root.activity - 0.02) / 0.25))

        // bars.
        Repeater {
            model: root.effStyle === "bars" ? root.bands : 0
            Rectangle {
                required property int index
                readonly property color c: root.bandColor(index)
                readonly property real len: root.lengthAt(index)
                width: root.barW
                x: index * root.slotW + (root.slotW - root.barW) / 2
                height: len
                y: root.barY(len)
                radius: root.capR
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(c, 1.25) }
                    GradientStop { position: 0.55; color: c }
                    GradientStop { position: 1.0; color: Qt.alpha(c, 0.35) }
                }
            }
        }

        // dots: a disc on the tip of each band.
        Repeater {
            model: root.effStyle === "dots" ? root.bands : 0
            Rectangle {
                required property int index
                readonly property color c: root.bandColor(index)
                readonly property real len: root.lengthAt(index)
                readonly property real d: Math.max(3 * root.ui, Math.min(root.slotW * 0.7, root.barW * 1.6))
                width: d
                height: d
                radius: Config.shape === "rounded" ? d / 2 : Math.min(3 * root.ui, d * 0.2)
                x: index * root.slotW + (root.slotW - d) / 2
                y: root.tipY(len) - d / 2
                antialiasing: true
                color: c
            }
        }

        // segments: each band a stack of fixed cells lit from the base to its
        // level. one flat repeater over band x cell, hidden cells not painted;
        // under heavy load the governor folds this back to plain bars.
        Repeater {
            model: root.effStyle === "segments" ? root.bands * root.segN : 0
            Rectangle {
                required property int index
                readonly property int band: Math.floor(index / root.segN)
                readonly property int cell: index % root.segN
                readonly property color c: root.bandColor(band)
                readonly property real len: root.lengthAt(band)
                readonly property int lit: Math.round(len / Math.max(1, root.maxBarH) * root.segN)
                readonly property real pitch: root.maxBarH / root.segN
                visible: cell < lit
                width: root.barW
                height: Math.max(2, pitch - root.segGap)
                x: band * root.slotW + (root.slotW - root.barW) / 2
                y: {
                    if (root.position === "top")
                        return cell * pitch + root.segGap / 2;
                    if (root.position === "center")
                        return root.cy - lit * pitch / 2 + cell * pitch + root.segGap / 2;
                    return root.baseBottom - (cell + 1) * pitch + root.segGap / 2;
                }
                radius: Config.shape === "rounded" ? Math.min(height, root.barW) * 0.35 : 0
                antialiasing: true
                color: Qt.lighter(c, 1 + 0.5 * (lit > 1 ? cell / (lit - 1) : 0))
            }
        }

        // wave: a smooth filled area under the band tips.
        Shape {
            id: area
            anchors.fill: parent
            visible: root.areaStyle
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: area.width
                    y2: 0
                    GradientStop { position: 0; color: Qt.alpha(Wallust.colorAt(0), 0.92) }
                    GradientStop { position: 0.1667; color: Qt.alpha(Wallust.colorAt(0.1667), 0.92) }
                    GradientStop { position: 0.3333; color: Qt.alpha(Wallust.colorAt(0.3333), 0.92) }
                    GradientStop { position: 0.5; color: Qt.alpha(Wallust.colorAt(0.5), 0.92) }
                    GradientStop { position: 0.6667; color: Qt.alpha(Wallust.colorAt(0.6667), 0.92) }
                    GradientStop { position: 0.8333; color: Qt.alpha(Wallust.colorAt(0.8333), 0.92) }
                    GradientStop { position: 1; color: Qt.alpha(Wallust.colorAt(1), 0.92) }
                }
                PathSvg { path: root.fillPath }
            }
        }

        // line: a stiff angular readout with its own soft halo behind the bright
        // filament, so it glows even when bloom is low. sharp miter corners.
        Shape {
            anchors.fill: parent
            visible: root.effStyle === "line"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Qt.lighter(Wallust.accent, 1.5), 0.22)
                strokeWidth: Math.max(7, 8 * root.ui)
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"
                PathSvg { path: root.linePath }
            }
        }
        Shape {
            anchors.fill: parent
            visible: root.effStyle === "line"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.lighter(Wallust.accent, 1.8)
                strokeWidth: Math.max(2.5, 2.8 * root.ui)
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin
                fillColor: "transparent"
                PathSvg { path: root.linePath }
            }
        }

        // radial: a ring of bars growing outward from a pulsing centre circle.
        Rectangle {
            id: ring
            visible: root.effStyle === "radial"
            readonly property real rr: root.ringR0 * (1 + 0.12 * root.maxLevel)
            width: ring.rr * 2
            height: ring.rr * 2
            radius: ring.rr
            x: root.cx - ring.rr
            y: root.cy - ring.rr
            color: "transparent"
            border.width: Math.max(1, 1.5 * root.ui)
            border.color: Qt.alpha(Wallust.accent, 0.4)
            antialiasing: true
        }
        Repeater {
            model: root.effStyle === "radial" ? root.bands : 0
            Rectangle {
                id: spoke
                required property int index
                readonly property color c: root.bandColor(spoke.index)
                readonly property real len: Math.max(2 * root.ui, root.ringMax * root.levelAt(spoke.index))
                width: root.radialArcW
                height: spoke.len
                x: root.cx - width / 2
                y: root.cy - root.ringR0 - spoke.len
                radius: Config.shape === "rounded" ? width / 2 : 0
                antialiasing: true
                transform: Rotation {
                    origin.x: root.radialArcW / 2
                    origin.y: root.ringR0 + spoke.len
                    angle: spoke.index / Math.max(1, root.bands) * 360
                }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(spoke.c, 1.2) }
                    GradientStop { position: 1.0; color: Qt.alpha(spoke.c, 0.5) }
                }
            }
        }

        // circle: a smooth closed blob whose radius at each angle is that band's
        // level, so the whole ring breathes and morphs with the music.
        Shape {
            id: blob
            anchors.fill: parent
            visible: root.effStyle === "circle"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.lighter(Wallust.accent, 1.5)
                strokeWidth: Math.max(2, 2.2 * root.ui)
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillGradient: LinearGradient {
                    x1: root.cx - root.ringR0 - root.ringMax
                    y1: 0
                    x2: root.cx + root.ringR0 + root.ringMax
                    y2: 0
                    GradientStop { position: 0; color: Qt.alpha(Wallust.colorAt(0), 0.3) }
                    GradientStop { position: 0.5; color: Qt.alpha(Wallust.colorAt(0.5), 0.3) }
                    GradientStop { position: 1; color: Qt.alpha(Wallust.colorAt(1), 0.3) }
                }
                PathSvg { path: root.circlePath }
            }
        }

        // falling peak caps above bars/segments.
        Repeater {
            model: root.wantPeaks ? root.bands : 0
            Rectangle {
                required property int index
                readonly property color c: root.bandColor(index)
                readonly property real pk: (root.peaks && index < root.peaks.length) ? root.peaks[index] : 0
                readonly property real plen: root.maxBarH * pk
                readonly property real capH: Math.max(2 * root.ui, 3)
                visible: pk > 0.02
                width: root.barW
                height: capH
                x: index * root.slotW + (root.slotW - root.barW) / 2
                y: root.position === "top" ? plen : root.baseBottom - plen - capH
                radius: Config.shape === "rounded" ? capH / 2 : 0
                antialiasing: true
                color: Qt.lighter(c, 1.5)
            }
        }
    }

    // quadratic-smoothed SVG segments through (xs, ys), forward or reverse.
    function svgSmooth(xs, ys, reverse) {
        var n = xs.length;
        var s = "";
        if (reverse) {
            for (var i = n - 1; i > 0; i--)
                s += "Q" + xs[i] + " " + ys[i] + " " + ((xs[i] + xs[i - 1]) / 2) + " " + ((ys[i] + ys[i - 1]) / 2) + " ";
            s += "Q" + xs[0] + " " + ys[0] + " " + xs[0] + " " + ys[0] + " ";
        } else {
            for (var k = 0; k < n - 1; k++)
                s += "Q" + xs[k] + " " + ys[k] + " " + ((xs[k] + xs[k + 1]) / 2) + " " + ((ys[k] + ys[k + 1]) / 2) + " ";
            s += "Q" + xs[n - 1] + " " + ys[n - 1] + " " + xs[n - 1] + " " + ys[n - 1] + " ";
        }
        return s;
    }
    function tipXs() {
        var xs = [];
        for (var i = 0; i < root.bands; i++)
            xs.push(i * root.slotW + root.slotW / 2);
        return xs;
    }
    function buildFillPath() {
        // once the spectrum settles flat there's nothing to draw. clear the
        // path so the fill disappears instead of freezing on its last frame.
        if (root.bands < 2 || root.maxLevel < 0.003)
            return "";
        var w = root.width;
        var xs = root.tipXs();
        if (root.position === "center") {
            var top = [], bot = [];
            for (var j = 0; j < root.bands; j++) {
                var ln = root.lengthAt(j);
                top.push(root.cy - ln / 2);
                bot.push(root.cy + ln / 2);
            }
            return "M" + xs[0] + " " + top[0] + " " + root.svgSmooth(xs, top, false)
                + "L" + xs[root.bands - 1] + " " + bot[root.bands - 1] + " " + root.svgSmooth(xs, bot, true) + "Z";
        }
        var baseY = root.position === "top" ? 0 : root.baseBottom;
        var ys = [];
        for (var m = 0; m < root.bands; m++)
            ys.push(root.tipY(root.lengthAt(m)));
        return "M0 " + baseY + " L" + xs[0] + " " + ys[0] + " " + root.svgSmooth(xs, ys, false)
            + "L" + w + " " + ys[root.bands - 1] + " L" + w + " " + baseY + " Z";
    }
    // line = a stiff angular polyline through the tips (no smoothing), a
    // reactive visualiser edge distinct from the wave's soft curve.
    function buildAnglePath() {
        if (root.bands < 2 || root.maxLevel < 0.003)
            return "";
        var xs = root.tipXs();
        var s = "M0 " + root.tipY(root.lengthAt(0));
        for (var i = 0; i < root.bands; i++)
            s += " L" + xs[i] + " " + root.tipY(root.lengthAt(i));
        s += " L" + root.width + " " + root.tipY(root.lengthAt(root.bands - 1));
        return s;
    }
    // circle = a closed smoothed loop in polar coords, radius per band = level.
    function buildCirclePath() {
        if (root.bands < 2 || root.maxLevel < 0.003)
            return "";
        var n = root.bands;
        var px = [], py = [];
        for (var i = 0; i < n; i++) {
            var ang = i / n * 2 * Math.PI - Math.PI / 2;
            var r = root.ringR0 + root.ringMax * root.levelAt(i);
            px.push(root.cx + Math.cos(ang) * r);
            py.push(root.cy + Math.sin(ang) * r);
        }
        var s = "M" + ((px[n - 1] + px[0]) / 2) + " " + ((py[n - 1] + py[0]) / 2) + " ";
        for (var k = 0; k < n; k++) {
            var nx = (k + 1) % n;
            s += "Q" + px[k] + " " + py[k] + " " + ((px[k] + px[nx]) / 2) + " " + ((py[k] + py[nx]) / 2) + " ";
        }
        return s + "Z";
    }
}
