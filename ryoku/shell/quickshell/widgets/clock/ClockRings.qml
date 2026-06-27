pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// rings face: three concentric arcs sweeping hour / minute / second, drawn
// from the wallust ramp so the whole dial retunes per wallpaper (the design
// where the palette IS the point). each ring rides a faint track with a
// round-capped progress arc; time sits digital in the centre. brand/mono
// accents fall back to graded shades of brand or ink.
Item {
    id: face

    readonly property var t: Clk.parts(Now.date, Config.clock24h)
    readonly property real s: Config.clockScale
    readonly property real dia: Math.round(232 * s)

    implicitWidth: dia
    implicitHeight: dia

    // repaint when time, palette, accent or size changes.
    readonly property var repaintKey: [Now.date, Config.clockAccent, Wallust.accent, face.dia, Config.clock24h]
    onRepaintKeyChanged: canvas.requestPaint()

    function css(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
    }
    function ringColor(i) {
        var f = [0.2, 0.5, 0.85][i];
        if (Config.clockAccent === "wallust")
            return face.css(Wallust.colorAt(f), 1);
        if (Config.clockAccent === "brand")
            return face.css(Qt.lighter(Theme.brand, 0.85 + i * 0.28), 1);
        return face.css(Theme.ink, 0.55 + i * 0.22);
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative
        onPaint: {
            var ctx = getContext("2d");
            var w = width;
            ctx.reset();
            ctx.clearRect(0, 0, w, w);
            var cx = w / 2, cy = w / 2;
            var lineW = w * 0.05;
            var gap = lineW * 1.75;
            var r0 = w / 2 - lineW * 0.7 - 2;
            var radii = [r0 - 2 * gap, r0 - gap, r0];   // hour, minute, second
            var fr = [
                ((face.t.hours % 12) + face.t.minutes / 60) / 12,
                (face.t.minutes + face.t.seconds / 60) / 60,
                face.t.seconds / 60
            ];
            for (var i = 0; i < 3; i++) {
                // track.
                ctx.beginPath();
                ctx.lineWidth = lineW;
                ctx.lineCap = "butt";
                ctx.strokeStyle = face.css(Theme.ink, 0.12);
                ctx.arc(cx, cy, radii[i], 0, 2 * Math.PI, false);
                ctx.stroke();
                // progress.
                if (fr[i] > 0.0001) {
                    ctx.beginPath();
                    ctx.lineWidth = lineW;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = face.ringColor(i);
                    ctx.arc(cx, cy, radii[i], -Math.PI / 2, -Math.PI / 2 + fr[i] * 2 * Math.PI, false);
                    ctx.stroke();
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 0

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.t.hh + ":" + face.t.mm
            color: Theme.ink
            font.family: Theme.mono
            font.pixelSize: Math.round(face.dia * 0.16)
            font.weight: Font.Bold
        }
        Text {
            visible: !Config.clock24h
            anchors.horizontalCenter: parent.horizontalCenter
            text: face.t.ampm
            color: Theme.inkDim
            font.family: Theme.mono
            font.pixelSize: Math.round(face.dia * 0.066)
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }
    }
}
