pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "Singletons"

// desktop spectrum. full-width cava analyser: bars | filled wave | floating
// dots, anchored bottom/top/centre, optional mirror. each band = a wallust
// colour so the whole sweep retunes with the wallpaper. soft bloom behind,
// fading reflection under bottom bars.
//
// motion = a Timer. ~60fps sounding, ~30fps for the idle wave, OFF when
// silent. decoupled from vsync so a 165Hz panel doesn't re-render every
// frame for nothing. per-band ease (fast attack, slow decay) plus an
// `activity` signal cross-fades live spectrum <-> calm idle wave, so quiet
// gaps fade instead of snapping off. look is live from the visualiser
// Config; Ryoku Settings edits it.
Item {
    id: root

    readonly property int bands: Spectrum.bars
    readonly property real ui: Math.max(0.75, height / 1080)

    readonly property string style: Config.style
    readonly property string position: Config.position
    readonly property bool mirror: Config.mirror

    readonly property bool reflects: root.style === "bars" && root.position === "bottom" && Config.reflection > 0
    readonly property real reflectionH: root.reflects ? Math.round(height * Config.reflection) : 0
    readonly property real maxBarH: Math.round(height * Config.height)
    readonly property real baseBottom: height - reflectionH
    readonly property real cy: height / 2
    readonly property real slotW: bands > 0 ? width / bands : width
    readonly property real barW: Math.max(2, slotW * Config.thickness)
    readonly property real capR: Config.shape === "rounded" ? root.barW / 2 : Math.min(3 * root.ui, root.barW * 0.2)

    // --- motion engine ------------------------------------------------------
    // smoothed per-band heights (0..1) + a 0..1 "is music playing" signal.
    // both eased per frame, nothing jumps.
    property var levels: []
    property real activity: 0
    property real idlePhase: 0
    property real maxLevel: 0
    property bool waveOn: false
    property string wavePath: ""
    // sounding = playing now, or just stopped and still easing down.
    readonly property bool sounding: Spectrum.energy > 0.04 || root.activity > 0.02
    // anything to animate at all? silent + settled + idle wave off -> ticker
    // stops cold (0 CPU on a quiet desktop) until sound returns. the opt-in
    // freeze drops the idle wave too, so a silent desktop is fully still.
    readonly property bool idleFrozen: Performance.freezeVisualizerWhenIdle && !AudioActivity.playing
    readonly property bool animating: root.sounding || (Config.idleWave && !root.idleFrozen) || root.maxLevel > 0.004

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
        return Math.pow(v, 0.72);
    }
    function idleLevel(i) {
        return 0.012 + 0.02 * (0.5 + 0.5 * Math.sin(root.srcIndex(i) * 0.4 + root.idlePhase));
    }

    Timer {
        id: ticker
        // panel can be 165Hz, cava only feeds 60. a FrameAnimation would still
        // re-render the whole scene every vsync for nothing. Timer decouples
        // update rate from refresh: ~60 sounding, ~30 idle wave, stops when
        // there's nothing to animate.
        interval: root.sounding ? 16 : 33
        running: root.visible && Config.enabled && root.animating
        repeat: true
        property real last: 0
        onTriggered: {
            var now = Date.now();
            var dt = last > 0 ? (now - last) / 1000 : interval / 1000;
            last = now;
            root.tick(Math.min(0.05, dt));
        }
    }
    function tick(dt) {
        // activity: fast rise on sound start, slow release so short gaps
        // don't flicker the spectrum off.
        var goal = Spectrum.energy > 0.04 ? 1 : 0;
        var aK = 1 - Math.exp(-dt / (goal > root.activity ? 0.05 : 1.1));
        root.activity += (goal - root.activity) * aK;
        if (Config.idleWave)
            root.idlePhase += dt * (Math.PI * 2 / 6);

        var n = root.bands;
        var prev = root.levels;
        var idleAmt = Config.idleWave ? (1 - root.activity) : 0;
        var out = new Array(n);
        for (var i = 0; i < n; i++) {
            var target = root.activity * root.rawLevel(i) + idleAmt * root.idleLevel(i);
            var cur = (prev && i < prev.length) ? prev[i] : 0;
            // fast attack, slow decay, frame-rate independent.
            var k = 1 - Math.exp(-dt / (target > cur ? 0.045 : 0.16));
            out[i] = cur + (target - cur) * k;
        }
        root.levels = out;
        var mx = 0;
        for (var j = 0; j < n; j++)
            if (out[j] > mx)
                mx = out[j];
        root.maxLevel = mx;
        if (root.style === "wave") {
            var show = Config.idleWave || mx > 0.003;
            if (show || root.waveOn) {
                root.wavePath = root.buildWavePath();
                root.waveOn = show;
            }
        }
    }

    function bandColor(i) {
        return Wallust.colorAt(root.bands > 1 ? i / (root.bands - 1) : 0.5);
    }
    function lengthAt(i) {
        var dl = root.levels;
        var v = (dl && i < dl.length) ? dl[i] : 0;
        // min sliver fades with the spectrum when idle wave is off, so a
        // silent desktop clears fully instead of leaving a thin line.
        var minH = 2 * root.ui * (Config.idleWave ? 1 : root.activity);
        return Math.max(minH, root.maxBarH * v);
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
        visible: root.position === "bottom"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.maxBarH * 0.7
        opacity: (Config.idleWave ? 0.08 : 0) + 0.34 * root.activity
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(Wallust.accent, 0.5) }
        }
    }

    // bloom = blurred copy of the crisp field sitting just behind it.
    MultiEffect {
        source: field
        anchors.fill: field
        z: 0
        // MultiEffect runs its GPU pass every visible frame even at low
        // opacity. skip it when the field is flat (silent, idle off).
        visible: root.maxLevel > 0.01
        blurEnabled: true
        blur: 1.0
        blurMax: 24
        autoPaddingEnabled: true
        opacity: Config.bloom * (0.5 + 0.5 * root.activity)
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

        // bars.
        Repeater {
            model: root.style === "bars" ? root.bands : 0
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
            model: root.style === "dots" ? root.bands : 0
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

        // wave: filled smoothed curve through the band tips. GPU Shape (not
        // a software Canvas), so the fill never touches the main thread.
        Shape {
            id: wave
            anchors.fill: parent
            visible: root.style === "wave"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: wave.width
                    y2: 0
                    GradientStop { position: 0; color: Qt.alpha(Wallust.colorAt(0), 0.92) }
                    GradientStop { position: 0.1667; color: Qt.alpha(Wallust.colorAt(0.1667), 0.92) }
                    GradientStop { position: 0.3333; color: Qt.alpha(Wallust.colorAt(0.3333), 0.92) }
                    GradientStop { position: 0.5; color: Qt.alpha(Wallust.colorAt(0.5), 0.92) }
                    GradientStop { position: 0.6667; color: Qt.alpha(Wallust.colorAt(0.6667), 0.92) }
                    GradientStop { position: 0.8333; color: Qt.alpha(Wallust.colorAt(0.8333), 0.92) }
                    GradientStop { position: 1; color: Qt.alpha(Wallust.colorAt(1), 0.92) }
                }
                PathSvg { path: root.wavePath }
            }
        }
    }

    // quadratic-smoothed SVG segments through (xs, ys), forward or reverse.
    // same curve the old Canvas drew, now a path string for the Shape.
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
    function buildWavePath() {
        // once the spectrum settles flat there's nothing to draw. clear the
        // path so the wave disappears instead of freezing on its last frame.
        if (root.bands < 2 || root.maxLevel < 0.003)
            return "";
        var w = root.width;
        var xs = [];
        for (var i = 0; i < root.bands; i++)
            xs.push(i * root.slotW + root.slotW / 2);
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
}
