pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons

// A self-contained, live preview of the desktop audio visualiser for the
// Desktop page's Visualizer subtab. The real renderer
// (ryoku/shell/quickshell/visualizer/Visualizer.qml) leans on shell-local
// singletons (Spectrum/Waveform/Scheme/Config/Performance) the hub cannot
// import, so this rebuilds a REPRESENTATIVE spectrum from a synthetic signal: a
// per-band travelling wave advanced by a ~30fps Timer, since the hub has no
// audio feed. It reads the live draft (style/position/shape/bars/thickness/
// height/mirror/segments), so the picture retunes as those knobs are edited.
//
// Monochrome by design -- app content carries no accent -- an ink ramp from
// Tokens, kept calm. bars, dots, segments, line and wave are drawn in full;
// radial and circle get a polar look, all on one Canvas so every style shares
// the same geometry the real analyser uses.
Item {
    id: root

    property var hub

    implicitHeight: 200
    // folds flat out of the layout on the General subtab (the page toggles
    // `visible`); the shared extras slot measures childrenRect, so the height
    // must actually reach 0 or an empty gap would push the settings down.
    height: visible ? implicitHeight : 0

    // ── live draft reads (defaults mirror vizA in Hub.qml) ──────────────────
    readonly property var d: (root.hub && root.hub.draft) ? root.hub.draft : ({})
    function pick(k, dflt) { var v = root.d[k]; return v === undefined ? dflt : v; }

    readonly property bool vEnabled: root.pick("enabled", true)
    // an unknown style (one dropped from the set) falls back to bars, as the
    // real renderer does, so a stale draft never paints blank.
    readonly property var knownStyles: ["bars", "dots", "line", "wave", "segments", "radial", "circle"]
    readonly property string vStyle: root.knownStyles.indexOf(root.pick("style", "bars")) >= 0 ? root.pick("style", "bars") : "bars"
    readonly property string vPosition: root.pick("position", "bottom")
    readonly property string vShape: root.pick("shape", "rounded")
    readonly property bool vMirror: root.pick("mirror", false)
    readonly property int vBars: Math.max(2, Math.min(128, Math.round(root.pick("bars", 64))))
    readonly property int vSeg: Math.max(4, Math.min(16, Math.round(root.pick("segments", 10))))
    readonly property real vThick: Math.max(0.1, Math.min(1, root.pick("thickness", 0.58)))
    readonly property real vHeight: Math.max(0.05, Math.min(0.95, root.pick("height", 0.42)))

    // ── synthetic motion ────────────────────────────────────────────────────
    // no audio in the hub, so a travelling wave stands in for cava: a bass-heavy
    // envelope with two drifting sines and a slow idle floor. one phase, nudged
    // each frame; the Canvas repaints when it (or any drawn knob) moves.
    property real phase: 0
    Timer {
        interval: Math.round(1000 / 30)
        running: root.visible && root.vEnabled
        repeat: true
        onTriggered: root.phase += 0.09
    }

    // mirror folds the band order symmetric around the centre -- bass in the
    // middle -- exactly as the real srcIndex does.
    function srcIndex(i) {
        if (!root.vMirror)
            return i;
        var c = Math.floor(root.vBars / 2);
        return Math.max(0, Math.min(root.vBars - 1, Math.abs(i - c)));
    }
    function levelAt(i) {
        var n = Math.max(1, root.vBars);
        var s = root.srcIndex(i);
        var t = s / n;
        var env = Math.pow(1 - t, 1.35) * 0.9 + 0.1;
        var w1 = 0.5 + 0.5 * Math.sin(s * 0.5 - root.phase * 2.1);
        var w2 = 0.5 + 0.5 * Math.sin(s * 0.17 + root.phase * 1.3);
        var idle = 0.10 + 0.06 * Math.sin(s * 0.4 + root.phase);
        var v = env * (0.32 + 0.68 * (0.6 * w1 + 0.4 * w2));
        return Math.max(idle, Math.max(0.02, Math.min(1, v)));
    }

    // the frame: flat, one hairline, Tokens radius -- the hub is print.
    Rectangle {
        anchors.fill: parent
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.line
    }

    // header: the // PREVIEW_ mark the other surfaces wear, and a live readout.
    Row {
        id: header
        anchors { left: parent.left; top: parent.top; margins: Tokens.s4 }
        spacing: Tokens.s2
        Text {
            text: "//"
            color: Tokens.inkFaint
            font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
            anchors.verticalCenter: parent.verticalCenter
        }
        Text {
            text: "PREVIEW_"
            color: Tokens.inkMuted
            font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
            font.letterSpacing: Tokens.trackLabel
            anchors.verticalCenter: parent.verticalCenter
        }
    }
    Text {
        anchors { right: parent.right; top: parent.top; margins: Tokens.s4 }
        text: root.vStyle.toUpperCase() + " \u00b7 " + root.vBars
        color: Tokens.inkFaint
        font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
    }

    // the stage the spectrum is painted on, inset under the header.
    Item {
        id: stage
        anchors {
            left: parent.left; right: parent.right
            top: header.bottom; bottom: parent.bottom
            leftMargin: Tokens.s4; rightMargin: Tokens.s4
            topMargin: Tokens.s3; bottomMargin: Tokens.s4
        }
        clip: true

        Canvas {
            id: cv
            anchors.fill: parent
            antialiasing: true
            visible: root.vEnabled

            // repaint whenever the motion advances or a drawn knob changes.
            readonly property var key: [root.phase, root.vStyle, root.vPosition, root.vShape,
                root.vMirror, root.vBars, root.vSeg, root.vThick, root.vHeight, cv.width, cv.height]
            onKeyChanged: cv.requestPaint()
            onVisibleChanged: if (cv.visible) cv.requestPaint()

            function css(c, a) {
                return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")";
            }
            // a rounded-rect path (arcTo), r clamped so slivers never bulge.
            function rr(ctx, x, y, w, h, r) {
                r = Math.max(0, Math.min(r, w / 2, h / 2));
                ctx.beginPath();
                ctx.moveTo(x + r, y);
                ctx.arcTo(x + w, y, x + w, y + h, r);
                ctx.arcTo(x + w, y + h, x, y + h, r);
                ctx.arcTo(x, y + h, x, y, r);
                ctx.arcTo(x, y, x + w, y, r);
                ctx.closePath();
            }

            onPaint: {
                var ctx = cv.getContext("2d");
                ctx.reset();
                var W = cv.width, H = cv.height;
                ctx.clearRect(0, 0, W, H);
                if (!root.vEnabled || W <= 1 || H <= 1)
                    return;

                var n = root.vBars;
                var slotW = W / n;
                var barW = Math.max(1.5, slotW * root.vThick);
                var maxH = Math.min(H, H * root.vHeight);
                var pos = root.vPosition;
                var rounded = root.vShape === "rounded";
                var ink = Tokens.ink;
                var style = root.vStyle;

                // a band's drawn length, floored to a sliver so nothing vanishes.
                function len(i) { return Math.max(1.5, maxH * root.levelAt(i)); }
                // top-left y of a bottom/top/centre bar of length L.
                function topY(L) { return pos === "top" ? 0 : pos === "center" ? (H - L) / 2 : H - L; }
                // the y of a band's growing tip.
                function tipY(L) { return pos === "top" ? L : pos === "center" ? (H - L) / 2 : H - L; }

                // ── bars ──────────────────────────────────────────────────
                if (style === "bars") {
                    for (var i = 0; i < n; i++) {
                        var L = len(i);
                        var x = i * slotW + (slotW - barW) / 2;
                        var y = topY(L);
                        var g = ctx.createLinearGradient(0, y, 0, y + L);
                        g.addColorStop(0, cv.css(ink, pos === "top" ? 0.30 : 0.95));
                        g.addColorStop(1, cv.css(ink, pos === "top" ? 0.95 : 0.30));
                        ctx.fillStyle = g;
                        cv.rr(ctx, x, y, barW, L, rounded ? barW / 2 : Math.min(2, barW * 0.2));
                        ctx.fill();
                    }
                    return;
                }

                // ── dots: a disc on each band's tip ───────────────────────
                if (style === "dots") {
                    var dsz = Math.max(2, Math.min(slotW * 0.72, barW * 1.7));
                    for (var j = 0; j < n; j++) {
                        var cxj = j * slotW + slotW / 2;
                        var cyj = tipY(len(j));
                        ctx.fillStyle = cv.css(ink, 0.55 + 0.4 * root.levelAt(j));
                        if (rounded) {
                            ctx.beginPath();
                            ctx.arc(cxj, cyj, dsz / 2, 0, 2 * Math.PI);
                            ctx.closePath();
                            ctx.fill();
                        } else {
                            cv.rr(ctx, cxj - dsz / 2, cyj - dsz / 2, dsz, dsz, Math.min(2, dsz * 0.2));
                            ctx.fill();
                        }
                    }
                    return;
                }

                // ── segments: each band a stack of lit cells ──────────────
                if (style === "segments") {
                    var segN = root.vSeg;
                    var pitch = maxH / segN;
                    var gap = Math.max(1.0, pitch * 0.26);
                    var sh = Math.max(1.5, pitch - gap);
                    for (var b = 0; b < n; b++) {
                        var lit = Math.round(len(b) / Math.max(1, maxH) * segN);
                        var bx = b * slotW + (slotW - barW) / 2;
                        for (var c2 = 0; c2 < lit; c2++) {
                            var sy;
                            if (pos === "top") sy = c2 * pitch + gap / 2;
                            else if (pos === "center") sy = H / 2 - lit * pitch / 2 + c2 * pitch + gap / 2;
                            else sy = H - (c2 + 1) * pitch + gap / 2;
                            ctx.fillStyle = cv.css(ink, 0.4 + 0.55 * (lit > 1 ? c2 / (lit - 1) : 1));
                            cv.rr(ctx, bx, sy, barW, sh, rounded ? Math.min(sh, barW) * 0.35 : 0);
                            ctx.fill();
                        }
                    }
                    return;
                }

                // ── line: a synthetic oscilloscope on a faint baseline ────
                if (style === "line") {
                    var amp = maxH * 0.5;
                    var base = pos === "top" ? amp * 1.15 : pos === "center" ? H / 2 : H - amp * 1.15;
                    var dir = pos === "top" ? -1 : 1;
                    ctx.strokeStyle = cv.css(ink, 0.18);
                    ctx.lineWidth = 1;
                    ctx.beginPath(); ctx.moveTo(0, base); ctx.lineTo(W, base); ctx.stroke();
                    var steps = Math.max(64, Math.min(160, Math.round(W / 4)));
                    ctx.beginPath();
                    for (var st = 0; st <= steps; st++) {
                        var tx = st / steps;
                        var win = Math.sin(Math.PI * tx);
                        var sig = Math.sin(tx * Math.PI * 8 - root.phase * 3) * 0.6
                                + Math.sin(tx * Math.PI * 17 + root.phase * 2) * 0.3
                                + Math.sin(tx * Math.PI * 3 - root.phase * 1.5) * 0.5;
                        var yy = base - dir * sig * amp * (0.35 + 0.65 * win);
                        if (st === 0) ctx.moveTo(0, yy); else ctx.lineTo(tx * W, yy);
                    }
                    ctx.strokeStyle = cv.css(ink, 0.9);
                    ctx.lineWidth = 2;
                    ctx.lineCap = rounded ? "round" : "butt";
                    ctx.lineJoin = "round";
                    ctx.stroke();
                    return;
                }

                // ── wave: a smooth filled area under the band tips ────────
                if (style === "wave") {
                    var xs = [], ys = [];
                    for (var m = 0; m < n; m++) {
                        xs.push(m * slotW + slotW / 2);
                        ys.push(tipY(len(m)));
                    }
                    var grad = ctx.createLinearGradient(0, 0, 0, H);
                    grad.addColorStop(0, cv.css(ink, pos === "top" ? 0.72 : 0.14));
                    grad.addColorStop(1, cv.css(ink, pos === "top" ? 0.14 : 0.72));
                    ctx.fillStyle = grad;
                    if (pos === "center") {
                        var bot = [];
                        for (var mb = 0; mb < n; mb++) bot.push(H / 2 + len(mb) / 2);
                        ctx.beginPath();
                        ctx.moveTo(xs[0], ys[0]);
                        for (var kt = 0; kt < n - 1; kt++)
                            ctx.quadraticCurveTo(xs[kt], ys[kt], (xs[kt] + xs[kt + 1]) / 2, (ys[kt] + ys[kt + 1]) / 2);
                        ctx.lineTo(xs[n - 1], ys[n - 1]);
                        ctx.lineTo(xs[n - 1], bot[n - 1]);
                        for (var kb = n - 1; kb > 0; kb--)
                            ctx.quadraticCurveTo(xs[kb], bot[kb], (xs[kb] + xs[kb - 1]) / 2, (bot[kb] + bot[kb - 1]) / 2);
                        ctx.lineTo(xs[0], bot[0]);
                        ctx.closePath();
                        ctx.fill();
                    } else {
                        var baseY = pos === "top" ? 0 : H;
                        ctx.beginPath();
                        ctx.moveTo(0, baseY);
                        ctx.lineTo(xs[0], ys[0]);
                        for (var kk = 0; kk < n - 1; kk++)
                            ctx.quadraticCurveTo(xs[kk], ys[kk], (xs[kk] + xs[kk + 1]) / 2, (ys[kk] + ys[kk + 1]) / 2);
                        ctx.lineTo(xs[n - 1], ys[n - 1]);
                        ctx.lineTo(W, ys[n - 1]);
                        ctx.lineTo(W, baseY);
                        ctx.closePath();
                        ctx.fill();
                    }
                    return;
                }

                // ── radial / circle: a centred polar look ─────────────────
                var ccx = W / 2, ccy = H / 2;
                var r0 = Math.min(W, H) * (0.14 + 0.10 * root.vHeight);
                var rMax = Math.min(W, H) * (0.10 + 0.24 * root.vHeight);
                if (style === "radial") {
                    ctx.strokeStyle = cv.css(ink, 0.4);
                    ctx.lineWidth = 1.5;
                    ctx.beginPath(); ctx.arc(ccx, ccy, r0, 0, 2 * Math.PI); ctx.stroke();
                    var arcW = Math.max(1.5, (2 * Math.PI * r0 / n) * root.vThick);
                    ctx.lineCap = rounded ? "round" : "butt";
                    for (var q = 0; q < n; q++) {
                        var Lr = Math.max(1.5, rMax * root.levelAt(q));
                        var ang = q / n * 2 * Math.PI - Math.PI / 2;
                        var cw = Math.cos(ang), sw = Math.sin(ang);
                        ctx.strokeStyle = cv.css(ink, 0.5 + 0.45 * root.levelAt(q));
                        ctx.lineWidth = arcW;
                        ctx.beginPath();
                        ctx.moveTo(ccx + cw * r0, ccy + sw * r0);
                        ctx.lineTo(ccx + cw * (r0 + Lr), ccy + sw * (r0 + Lr));
                        ctx.stroke();
                    }
                    return;
                }
                // circle: a smoothed closed blob, radius per band = its level.
                var px = [], py = [];
                for (var u = 0; u < n; u++) {
                    var au = u / n * 2 * Math.PI - Math.PI / 2;
                    var ru = r0 + rMax * root.levelAt(u);
                    px.push(ccx + Math.cos(au) * ru);
                    py.push(ccy + Math.sin(au) * ru);
                }
                ctx.beginPath();
                ctx.moveTo((px[n - 1] + px[0]) / 2, (py[n - 1] + py[0]) / 2);
                for (var vv = 0; vv < n; vv++) {
                    var nx = (vv + 1) % n;
                    ctx.quadraticCurveTo(px[vv], py[vv], (px[vv] + px[nx]) / 2, (py[vv] + py[nx]) / 2);
                }
                ctx.closePath();
                ctx.fillStyle = cv.css(ink, 0.12);
                ctx.fill();
                ctx.strokeStyle = cv.css(ink, 0.85);
                ctx.lineWidth = 2;
                ctx.lineJoin = "round";
                ctx.stroke();
            }
        }
    }

    // off state: a calm placeholder, no red -- the hub's hazard voice is
    // black and white and reads as more serious for it.
    Text {
        anchors.centerIn: stage
        visible: !root.vEnabled
        text: "VISUALIZER OFF"
        color: Tokens.inkMuted
        font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
        font.weight: Font.Medium; font.letterSpacing: 2
    }

    onVisibleChanged: if (root.visible) cv.requestPaint()
    Component.onCompleted: cv.requestPaint()
}
