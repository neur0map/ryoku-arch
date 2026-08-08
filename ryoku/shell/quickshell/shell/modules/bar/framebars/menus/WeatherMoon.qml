import QtQuick
import shell.services

// A single crisp moon disc drawn from the daemon's phase data. `frac` is the
// illuminated fraction (0 new .. 1 full) and `waxing` picks the lit limb (right
// when waxing, left when waning, Northern-hemisphere convention). The night
// side fills the disc, the lit hemisphere paints over it, and the terminator is
// a scaled circle that carves a crescent (frac < 0.5) or extends a gibbous
// (frac > 0.5). Used both as the current-phase glyph and across the 8-phase
// strip; the caller tints `litColor` to light the active phase.
Canvas {
    id: moon

    property real frac: 0
    property bool waxing: true
    property color litColor: Theme.onSurface
    property color darkColor: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.14)
    property color rimColor: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.30)

    onFracChanged: requestPaint()
    onWaxingChanged: requestPaint()
    onLitColorChanged: requestPaint()
    onDarkColorChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const sz = Math.min(width, height);
        const r = sz / 2;
        const cx = width / 2, cy = height / 2;

        ctx.reset();
        ctx.clearRect(0, 0, width, height);

        // Clip everything to the lunar disc.
        ctx.beginPath();
        ctx.arc(cx, cy, r, 0, 2 * Math.PI);
        ctx.closePath();
        ctx.save();
        ctx.clip();

        // Night side.
        ctx.fillStyle = moon.darkColor;
        ctx.fillRect(cx - r, cy - r, sz, sz);

        // Lit hemisphere.
        ctx.fillStyle = moon.litColor;
        if (moon.waxing)
            ctx.fillRect(cx, cy - r, r, sz);
        else
            ctx.fillRect(cx - r, cy - r, r, sz);

        // Terminator: a circle squashed on x, dark for a crescent, lit for a
        // gibbous. Zero width at the quarters leaves a clean half.
        const rx = r * Math.abs(1 - 2 * moon.frac);
        if (rx > 0.01) {
            ctx.fillStyle = (moon.frac < 0.5) ? moon.darkColor : moon.litColor;
            ctx.save();
            ctx.translate(cx, cy);
            ctx.scale(rx / r, 1);
            ctx.beginPath();
            ctx.arc(0, 0, r, 0, 2 * Math.PI);
            ctx.closePath();
            ctx.fill();
            ctx.restore();
        }
        ctx.restore();

        // Rim.
        ctx.beginPath();
        ctx.arc(cx, cy, r - 0.5, 0, 2 * Math.PI);
        ctx.lineWidth = 1;
        ctx.strokeStyle = moon.rimColor;
        ctx.stroke();
    }
}
