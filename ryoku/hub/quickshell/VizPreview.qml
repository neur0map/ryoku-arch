pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import "Singletons"

// live plain-QML preview of the desktop visualiser, driven by a synthetic
// "music" spectrum so the chosen style, shape, position, mirroring, peaks and
// segments show at a glance without the real spectrum (which lives behind your
// windows). mirrors the renderer in
// ryoku/shell/quickshell/visualizer/Visualizer.qml. colours = a representative
// ramp (the real spectrum follows your wallpaper); fps and the adaptive
// governor are runtime-only, so they don't appear here.
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
    property bool peaks: false
    property int segments: 10

    clip: true

    readonly property var knownStyles: ["bars", "dots", "line", "wave", "segments", "radial", "circle"]
    readonly property string vs: preview.knownStyles.indexOf(preview.style) >= 0 ? preview.style : "bars"

    readonly property int n: Math.max(2, Math.min(96, preview.bars))
    readonly property bool polar: preview.vs === "radial" || preview.vs === "circle"
    readonly property bool reflects: preview.vs === "bars" && preview.position === "bottom" && preview.reflection > 0
    readonly property real reflectionH: preview.reflects ? height * preview.reflection : 0
    readonly property real maxH: height * preview.heightFrac
    readonly property real baseBottom: height - reflectionH
    readonly property real cx: width / 2
    readonly property real cy: height / 2
    readonly property real slotW: width / n
    readonly property real barW: Math.max(2, slotW * preview.thickness)
    readonly property real capR: preview.shape === "rounded" ? barW / 2 : Math.min(2, barW * 0.2)

    readonly property int segN: Math.max(4, Math.min(16, preview.segments))
    readonly property real segGap: Math.max(1.5, preview.maxH / preview.segN * 0.26)

    readonly property real ringR0: Math.min(width, height) * (0.10 + 0.06 * preview.heightFrac)
    readonly property real ringMax: Math.min(width, height) * (0.10 + 0.22 * preview.heightFrac)
    readonly property real radialArcW: Math.max(2, (2 * Math.PI * preview.ringR0 / Math.max(1, preview.n)) * preview.thickness)

    readonly property bool areaStyle: preview.vs === "wave"
    readonly property bool wantPeaks: preview.peaks && preview.position !== "center"
        && (preview.vs === "bars" || preview.vs === "segments")

    readonly property var ramp: [[1.0, 0.478, 0.239], [1.0, 0.698, 0.302], [0.525, 0.831, 0.447], [0.302, 0.784, 0.902], [0.604, 0.482, 1.0]]
    function colorAt(t) {
        var s = preview.ramp, m = s.length;
        var x = Math.max(0, Math.min(0.9999, t)) * (m - 1);
        var i = Math.floor(x), f = x - i, a = s[i], b = s[i + 1];
        return Qt.rgba(a[0] + (b[0] - a[0]) * f, a[1] + (b[1] - a[1]) * f, a[2] + (b[2] - a[2]) * f, 1);
    }
    function bandColor(i) { return preview.colorAt(preview.n > 1 ? i / (preview.n - 1) : 0.5); }
    readonly property color accent: preview.colorAt(0.7)

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

    // desktop stand-in so the spectrum reads against something.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#191320" }
            GradientStop { position: 1.0; color: "#241a16" }
        }
    }

    Rectangle {
        visible: preview.position === "bottom" && !preview.polar
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
        visible: preview.reflects

        Repeater {
            model: preview.reflects ? preview.n : 0
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
            model: preview.vs === "bars" ? preview.n : 0
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
            model: preview.vs === "dots" ? preview.n : 0
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

        Repeater {
            model: preview.vs === "segments" ? preview.n * preview.segN : 0
            Rectangle {
                required property int index
                readonly property int band: Math.floor(index / preview.segN)
                readonly property int cell: index % preview.segN
                readonly property color c: preview.bandColor(band)
                readonly property real len: preview.lengthAt(band)
                readonly property int lit: Math.round(len / Math.max(1, preview.maxH) * preview.segN)
                readonly property real pitch: preview.maxH / preview.segN
                visible: cell < lit
                width: preview.barW
                height: Math.max(2, pitch - preview.segGap)
                x: band * preview.slotW + (preview.slotW - preview.barW) / 2
                y: {
                    if (preview.position === "top")
                        return cell * pitch + preview.segGap / 2;
                    if (preview.position === "center")
                        return preview.cy - lit * pitch / 2 + cell * pitch + preview.segGap / 2;
                    return preview.baseBottom - (cell + 1) * pitch + preview.segGap / 2;
                }
                radius: preview.shape === "rounded" ? Math.min(height, preview.barW) * 0.35 : 0
                antialiasing: true
                color: Qt.lighter(c, 1 + 0.5 * (lit > 1 ? cell / (lit - 1) : 0))
            }
        }

        Shape {
            id: area
            anchors.fill: parent
            visible: preview.areaStyle
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: "transparent"
                fillGradient: LinearGradient {
                    x1: 0
                    y1: 0
                    x2: area.width
                    y2: 0
                    GradientStop { position: 0; color: Qt.alpha(preview.colorAt(0), 0.92) }
                    GradientStop { position: 0.25; color: Qt.alpha(preview.colorAt(0.25), 0.92) }
                    GradientStop { position: 0.5; color: Qt.alpha(preview.colorAt(0.5), 0.92) }
                    GradientStop { position: 0.75; color: Qt.alpha(preview.colorAt(0.75), 0.92) }
                    GradientStop { position: 1; color: Qt.alpha(preview.colorAt(1), 0.92) }
                }
                PathSvg { path: preview.areaStyle ? preview.buildFillPath() : "" }
            }
        }

        Shape {
            anchors.fill: parent
            visible: preview.vs === "line"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.alpha(Qt.lighter(preview.accent, 1.5), 0.22)
                strokeWidth: 7
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.RoundJoin
                fillColor: "transparent"
                PathSvg { path: preview.vs === "line" ? preview.buildAnglePath() : "" }
            }
        }
        Shape {
            anchors.fill: parent
            visible: preview.vs === "line"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.lighter(preview.accent, 1.8)
                strokeWidth: 2.4
                capStyle: ShapePath.FlatCap
                joinStyle: ShapePath.MiterJoin
                fillColor: "transparent"
                PathSvg { path: preview.vs === "line" ? preview.buildAnglePath() : "" }
            }
        }

        Rectangle {
            id: ring
            visible: preview.vs === "radial"
            readonly property real rr: preview.ringR0 * (1 + 0.12 * preview.level(0))
            width: ring.rr * 2
            height: ring.rr * 2
            radius: ring.rr
            x: preview.cx - ring.rr
            y: preview.cy - ring.rr
            color: "transparent"
            border.width: 1.5
            border.color: Qt.alpha(preview.accent, 0.4)
            antialiasing: true
        }
        Repeater {
            model: preview.vs === "radial" ? preview.n : 0
            Rectangle {
                id: spoke
                required property int index
                readonly property color c: preview.bandColor(spoke.index)
                readonly property real len: Math.max(2, preview.ringMax * preview.level(spoke.index))
                width: preview.radialArcW
                height: spoke.len
                x: preview.cx - width / 2
                y: preview.cy - preview.ringR0 - spoke.len
                radius: preview.shape === "rounded" ? width / 2 : 0
                antialiasing: true
                transform: Rotation {
                    origin.x: preview.radialArcW / 2
                    origin.y: preview.ringR0 + spoke.len
                    angle: spoke.index / Math.max(1, preview.n) * 360
                }
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(spoke.c, 1.2) }
                    GradientStop { position: 1.0; color: Qt.alpha(spoke.c, 0.5) }
                }
            }
        }

        Shape {
            id: blob
            anchors.fill: parent
            visible: preview.vs === "circle"
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Qt.lighter(preview.accent, 1.5)
                strokeWidth: 2.2
                capStyle: ShapePath.RoundCap
                joinStyle: ShapePath.RoundJoin
                fillGradient: LinearGradient {
                    x1: preview.cx - preview.ringR0 - preview.ringMax
                    y1: 0
                    x2: preview.cx + preview.ringR0 + preview.ringMax
                    y2: 0
                    GradientStop { position: 0; color: Qt.alpha(preview.colorAt(0), 0.3) }
                    GradientStop { position: 0.5; color: Qt.alpha(preview.colorAt(0.5), 0.3) }
                    GradientStop { position: 1; color: Qt.alpha(preview.colorAt(1), 0.3) }
                }
                PathSvg { path: preview.vs === "circle" ? preview.buildCirclePath() : "" }
            }
        }

        Repeater {
            model: preview.wantPeaks ? preview.n : 0
            Rectangle {
                required property int index
                readonly property color c: preview.bandColor(index)
                readonly property real plen: preview.maxH * Math.min(1, preview.level(index) * 1.08 + 0.08)
                readonly property real capH: 3
                width: preview.barW
                height: capH
                x: index * preview.slotW + (preview.slotW - preview.barW) / 2
                y: preview.position === "top" ? plen : preview.baseBottom - plen - capH
                radius: preview.shape === "rounded" ? capH / 2 : 0
                antialiasing: true
                color: Qt.lighter(c, 1.5)
            }
        }
    }

    function svgSmooth(xs, ys, reverse) {
        var len = xs.length, s = "";
        if (reverse) {
            for (var i = len - 1; i > 0; i--)
                s += "Q" + xs[i] + " " + ys[i] + " " + ((xs[i] + xs[i - 1]) / 2) + " " + ((ys[i] + ys[i - 1]) / 2) + " ";
            s += "Q" + xs[0] + " " + ys[0] + " " + xs[0] + " " + ys[0] + " ";
        } else {
            for (var k = 0; k < len - 1; k++)
                s += "Q" + xs[k] + " " + ys[k] + " " + ((xs[k] + xs[k + 1]) / 2) + " " + ((ys[k] + ys[k + 1]) / 2) + " ";
            s += "Q" + xs[len - 1] + " " + ys[len - 1] + " " + xs[len - 1] + " " + ys[len - 1] + " ";
        }
        return s;
    }
    function tipXs() {
        var xs = [];
        for (var i = 0; i < preview.n; i++)
            xs.push(i * preview.slotW + preview.slotW / 2);
        return xs;
    }
    function buildFillPath() {
        var w = preview.width, xs = preview.tipXs();
        if (preview.position === "center") {
            var top = [], bot = [];
            for (var j = 0; j < preview.n; j++) {
                var ln = preview.lengthAt(j);
                top.push(preview.cy - ln / 2);
                bot.push(preview.cy + ln / 2);
            }
            return "M" + xs[0] + " " + top[0] + " " + preview.svgSmooth(xs, top, false)
                + "L" + xs[preview.n - 1] + " " + bot[preview.n - 1] + " " + preview.svgSmooth(xs, bot, true) + "Z";
        }
        var baseY = preview.position === "top" ? 0 : preview.baseBottom;
        var ys = [];
        for (var m = 0; m < preview.n; m++)
            ys.push(preview.tipY(preview.lengthAt(m)));
        return "M0 " + baseY + " L" + xs[0] + " " + ys[0] + " " + preview.svgSmooth(xs, ys, false)
            + "L" + w + " " + ys[preview.n - 1] + " L" + w + " " + baseY + " Z";
    }
    function buildAnglePath() {
        var xs = preview.tipXs();
        var s = "M0 " + preview.tipY(preview.lengthAt(0));
        for (var i = 0; i < preview.n; i++)
            s += " L" + xs[i] + " " + preview.tipY(preview.lengthAt(i));
        s += " L" + preview.width + " " + preview.tipY(preview.lengthAt(preview.n - 1));
        return s;
    }
    function buildCirclePath() {
        var nn = preview.n;
        var px = [], py = [];
        for (var i = 0; i < nn; i++) {
            var ang = i / nn * 2 * Math.PI - Math.PI / 2;
            var r = preview.ringR0 + preview.ringMax * preview.level(i);
            px.push(preview.cx + Math.cos(ang) * r);
            py.push(preview.cy + Math.sin(ang) * r);
        }
        var s = "M" + ((px[nn - 1] + px[0]) / 2) + " " + ((py[nn - 1] + py[0]) / 2) + " ";
        for (var k = 0; k < nn; k++) {
            var nx = (k + 1) % nn;
            s += "Q" + px[k] + " " + py[k] + " " + ((px[k] + px[nx]) / 2) + " " + ((py[k] + py[nx]) / 2) + " ";
        }
        return s + "Z";
    }
}
