pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

/**
 * The desktop spectrum. A full-width cava analyser drawn in the configured style,
 * bars, a filled wave, or floating dots, anchored to the bottom, top, or centre,
 * with optional mirroring. Every band is a vivified wallust colour (so the whole
 * sweep retunes per wallpaper), with a soft bloom behind it and, for bottom bars,
 * a fading reflection.
 *
 * Motion runs off a single per-frame ticker (FrameAnimation) so every style moves
 * at the display's refresh rate: each band eases toward its target (fast attack,
 * slow decay) and an `activity` signal eases between the live spectrum and a calm
 * idle wave, so quiet gaps fade in and out smoothly instead of snapping off. The
 * look is read live from the visualiser Config; Ryoku Settings edits it.
 */
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
    // Smoothed per-band heights (0..1) and a 0..1 "music is playing" signal,
    // both eased every frame so nothing ever jumps.
    property var levels: []
    property real activity: 0
    property real idlePhase: 0
    property real maxLevel: 0
    property bool waveOn: false

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

    FrameAnimation {
        id: ticker
        running: root.visible && Config.enabled
        onTriggered: root.tick(Math.min(0.05, frameTime))
    }
    function tick(dt) {
        // Activity: rises fast when sound starts, releases slowly so short gaps
        // do not flicker the spectrum off.
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
            // Fast attack, slower decay, frame-rate independent.
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
                wave.requestPaint();
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
        // The minimum sliver fades with the spectrum when the idle wave is off, so a
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

    // Ambient floor glow grounding bottom spectra; warms with overall energy.
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

    // Soft bloom: a blurred copy of the crisp field sitting just behind it.
    MultiEffect {
        source: field
        anchors.fill: field
        z: 0
        blurEnabled: true
        blur: 1.0
        blurMax: 40
        autoPaddingEnabled: true
        opacity: Config.bloom * (0.5 + 0.5 * root.activity)
    }

    // Reflection: the bottom bars mirrored below the baseline, each fading down.
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

    // The field: the active style, drawn crisp.
    Item {
        id: field
        anchors.fill: parent
        z: 1

        // Bars.
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

        // Dots: a disc riding the tip of each band.
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

        // Wave: a filled, smoothed curve through the band tips, repainted each frame.
        Canvas {
            id: wave
            anchors.fill: parent
            visible: root.style === "wave"
            renderStrategy: Canvas.Cooperative
            onPaint: root.paintWave(wave)
        }
    }

    // Quadratic-smoothed polyline through (xs, ys), forward or reversed.
    function smoothCurve(ctx, xs, ys, reverse) {
        var n = xs.length;
        if (reverse) {
            for (var i = n - 1; i > 0; i--)
                ctx.quadraticCurveTo(xs[i], ys[i], (xs[i] + xs[i - 1]) / 2, (ys[i] + ys[i - 1]) / 2);
            ctx.quadraticCurveTo(xs[0], ys[0], xs[0], ys[0]);
        } else {
            for (var k = 0; k < n - 1; k++)
                ctx.quadraticCurveTo(xs[k], ys[k], (xs[k] + xs[k + 1]) / 2, (ys[k] + ys[k + 1]) / 2);
            ctx.quadraticCurveTo(xs[n - 1], ys[n - 1], xs[n - 1], ys[n - 1]);
        }
    }
    function paintWave(cv) {
        var ctx = cv.getContext("2d");
        var w = cv.width;
        ctx.reset();
        // Nothing to draw once the spectrum has settled flat: leave the canvas clear
        // so the wave fully disappears instead of freezing on its last frame.
        if (root.bands < 2 || root.maxLevel < 0.003)
            return;

        var grad = ctx.createLinearGradient(0, 0, w, 0);
        for (var s = 0; s <= 6; s++)
            grad.addColorStop(s / 6, root.bandColor(Math.round((s / 6) * (root.bands - 1))));

        var xs = [];
        for (var i = 0; i < root.bands; i++)
            xs.push(i * root.slotW + root.slotW / 2);

        ctx.beginPath();
        if (root.position === "center") {
            var top = [], bot = [];
            for (var j = 0; j < root.bands; j++) {
                var ln = root.lengthAt(j);
                top.push(root.cy - ln / 2);
                bot.push(root.cy + ln / 2);
            }
            ctx.moveTo(xs[0], top[0]);
            root.smoothCurve(ctx, xs, top, false);
            ctx.lineTo(xs[root.bands - 1], bot[root.bands - 1]);
            root.smoothCurve(ctx, xs, bot, true);
        } else {
            var baseY = root.position === "top" ? 0 : root.baseBottom;
            var ys = [];
            for (var m = 0; m < root.bands; m++)
                ys.push(root.tipY(root.lengthAt(m)));
            ctx.moveTo(0, baseY);
            ctx.lineTo(xs[0], ys[0]);
            root.smoothCurve(ctx, xs, ys, false);
            ctx.lineTo(w, ys[root.bands - 1]);
            ctx.lineTo(w, baseY);
        }
        ctx.closePath();
        ctx.globalAlpha = 0.92;
        ctx.fillStyle = grad;
        ctx.fill();
    }
}
