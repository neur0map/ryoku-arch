pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import "Singletons"

// A live, plain-QML preview of the desktop visualiser, driven by a synthetic
// "music" spectrum so the chosen style, shape, position and mirroring show at a
// glance without the real spectrum (which lives behind your windows). It mirrors
// the renderer in ryoku/shell/quickshell/visualizer/Visualizer.qml; the colours
// are a representative ramp (the real spectrum follows your wallpaper).
Item {
    id: preview

    property string style: "bars"
    property string shape: "rounded"
    property string position: "bottom"
    property bool mirror: false
    property int bars: 64
    property real heightFrac: 0.42
    property real thickness: 0.58
    property real bloom: 0.6
    property real reflection: 0.1
    property bool enabled: true

    clip: true

    readonly property int n: Math.max(2, Math.min(96, preview.bars))
    readonly property real reflectionH: (preview.style === "bars" && preview.position === "bottom" && preview.reflection > 0)
        ? height * preview.reflection : 0
    readonly property real maxH: height * preview.heightFrac
    readonly property real baseBottom: height - reflectionH
    readonly property real cy: height / 2
    readonly property real slotW: width / n
    readonly property real barW: Math.max(2, slotW * preview.thickness)
    readonly property real capR: preview.shape === "rounded" ? barW / 2 : Math.min(2, barW * 0.2)

    readonly property var ramp: [[1.0, 0.478, 0.239], [1.0, 0.698, 0.302], [0.525, 0.831, 0.447], [0.302, 0.784, 0.902], [0.604, 0.482, 1.0]]
    function colorAt(t) {
        var s = preview.ramp, m = s.length;
        var x = Math.max(0, Math.min(0.9999, t)) * (m - 1);
        var i = Math.floor(x), f = x - i, a = s[i], b = s[i + 1];
        return Qt.rgba(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, 1);
    }
    function bandColor(i) { return preview.colorAt(preview.n > 1 ? i / (preview.n - 1) : 0.5); }

    property real phase: 0
    NumberAnimation on phase {
        from: 0; to: Math.PI * 2; duration: 2600
        loops: Animation.Infinite; running: preview.enabled
    }
    property real beat: 0.5
    SequentialAnimation on beat {
        loops: Animation.Infinite; running: preview.enabled
        NumberAnimation { from: 0.35; to: 1; duration: 360; easing.type: Easing.OutCubic }
        NumberAnimation { from: 1; to: 0.35; duration: 600; easing.type: Easing.InCubic }
    }

    function srcIndex(i) {
        if (!preview.mirror)
            return i;
        return Math.max(0, Math.min(preview.n - 1, Math.abs(i - Math.floor(preview.n / 2))));
    }
    function level(i) {
        var s = preview.srcIndex(i);
        var f = preview.n > 1 ? s / (preview.n - 1) : 0.5;
        var bass = Math.pow(1 - f, 1.5);
        var ripple = (0.5 + 0.5 * Math.sin(s * 0.5 + preview.phase * 3)) * (0.5 + 0.5 * Math.sin(s * 0.17 - preview.phase * 1.7));
        var v = (0.12 + 0.72 * bass) * (0.32 + 0.68 * ripple) * (0.45 + 0.7 * preview.beat);
        return Math.max(0.04, Math.min(1, v));
    }
    function lengthAt(i) { return Math.max(2, preview.maxH * preview.level(i)); }
    function barY(len) {
        if (preview.position === "top") return 0;
        if (preview.position === "center") return preview.cy - len / 2;
        return preview.baseBottom - len;
    }
    function tipY(len) {
        if (preview.position === "top") return len;
        if (preview.position === "center") return preview.cy - len / 2;
        return preview.baseBottom - len;
    }

    // Desktop stand-in so the spectrum reads against something.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#191320" }
            GradientStop { position: 1.0; color: "#241a16" }
        }
    }

    Rectangle {
        visible: preview.position === "bottom"
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: preview.maxH * 0.7
        opacity: preview.enabled ? 0.22 : 0.05
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(1, 0.55, 0.3, 0.4) }
        }
    }

    MultiEffect {
        source: field
        anchors.fill: field
        z: 0
        blurEnabled: true
        blur: 1.0
        blurMax: 28
        autoPaddingEnabled: true
        opacity: (preview.enabled ? preview.bloom : 0) * 0.8
    }

    Item {
        x: 0
        y: preview.baseBottom
        width: preview.width
        height: preview.reflectionH
        opacity: preview.enabled ? 0.4 : 0
        visible: preview.reflectionH > 0

        Repeater {
            model: preview.reflectionH > 0 ? preview.n : 0
            Rectangle {
                required property int index
                readonly property color c: preview.bandColor(index)
                width: preview.barW
                x: index * preview.slotW + (preview.slotW - preview.barW) / 2
                height: Math.min(preview.reflectionH, preview.maxH * preview.level(index) * 0.5)
                radius: preview.capR
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(c, 0.32) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }
    }

    Item {
        id: field
        anchors.fill: parent
        z: 1
        opacity: preview.enabled ? 1 : 0.16

        Repeater {
            model: preview.style === "bars" ? preview.n : 0
            Rectangle {
                required property int index
                readonly property color c: preview.bandColor(index)
                readonly property real len: preview.lengthAt(index)
                width: preview.barW
                x: index * preview.slotW + (preview.slotW - preview.barW) / 2
                height: len
                y: preview.barY(len)
                radius: preview.capR
                antialiasing: true
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(c, 1.25) }
                    GradientStop { position: 0.55; color: c }
                    GradientStop { position: 1.0; color: Qt.alpha(c, 0.35) }
                }
            }
        }

        Repeater {
            model: preview.style === "dots" ? preview.n : 0
            Rectangle {
                required property int index
                readonly property color c: preview.bandColor(index)
                readonly property real len: preview.lengthAt(index)
                readonly property real d: Math.max(3, Math.min(preview.slotW * 0.7, preview.barW * 1.6))
                width: d
                height: d
                radius: preview.shape === "rounded" ? d / 2 : Math.min(2, d * 0.2)
                x: index * preview.slotW + (preview.slotW - d) / 2
                y: preview.tipY(len) - d / 2
                antialiasing: true
                color: c
            }
        }

        Canvas {
            id: wave
            anchors.fill: parent
            visible: preview.style === "wave"
            renderStrategy: Canvas.Cooperative
            onPaint: preview.paintWave(wave)

            FrameAnimation {
                running: wave.visible
                onTriggered: wave.requestPaint()
            }
        }
    }

    function smoothCurve(ctx, xs, ys, reverse) {
        var len = xs.length;
        if (reverse) {
            for (var i = len - 1; i > 0; i--)
                ctx.quadraticCurveTo(xs[i], ys[i], (xs[i] + xs[i - 1]) / 2, (ys[i] + ys[i - 1]) / 2);
            ctx.quadraticCurveTo(xs[0], ys[0], xs[0], ys[0]);
        } else {
            for (var k = 0; k < len - 1; k++)
                ctx.quadraticCurveTo(xs[k], ys[k], (xs[k] + xs[k + 1]) / 2, (ys[k] + ys[k + 1]) / 2);
            ctx.quadraticCurveTo(xs[len - 1], ys[len - 1], xs[len - 1], ys[len - 1]);
        }
    }
    function paintWave(cv) {
        var ctx = cv.getContext("2d");
        var w = cv.width;
        ctx.reset();
        var grad = ctx.createLinearGradient(0, 0, w, 0);
        for (var s = 0; s <= 6; s++)
            grad.addColorStop(s / 6, preview.bandColor(Math.round((s / 6) * (preview.n - 1))));

        var xs = [];
        for (var i = 0; i < preview.n; i++)
            xs.push(i * preview.slotW + preview.slotW / 2);

        ctx.beginPath();
        if (preview.position === "center") {
            var top = [], bot = [];
            for (var j = 0; j < preview.n; j++) {
                var ln = preview.lengthAt(j);
                top.push(preview.cy - ln / 2);
                bot.push(preview.cy + ln / 2);
            }
            ctx.moveTo(xs[0], top[0]);
            preview.smoothCurve(ctx, xs, top, false);
            ctx.lineTo(xs[preview.n - 1], bot[preview.n - 1]);
            preview.smoothCurve(ctx, xs, bot, true);
        } else {
            var baseY = preview.position === "top" ? 0 : preview.baseBottom;
            var ys = [];
            for (var m = 0; m < preview.n; m++)
                ys.push(preview.tipY(preview.lengthAt(m)));
            ctx.moveTo(0, baseY);
            ctx.lineTo(xs[0], ys[0]);
            preview.smoothCurve(ctx, xs, ys, false);
            ctx.lineTo(w, ys[preview.n - 1]);
            ctx.lineTo(w, baseY);
        }
        ctx.closePath();
        ctx.globalAlpha = preview.enabled ? 0.92 : 0.16;
        ctx.fillStyle = grad;
        ctx.fill();
    }
}
