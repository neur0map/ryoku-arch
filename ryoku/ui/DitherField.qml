import QtQuick
import "Singletons"

// Procedural 1-bit dither art, generated in-engine (no asset): fractal
// value-noise thresholded through a 4x4 Bayer matrix into chunky bone pixels on
// black -- the etched, halftone, newsprint texture of the reference posters.
// Static: it paints once, gated on visibility, so the per-pixel JS is a one-time
// cost. Tune `freq` / `bias` / `seed` for a different field each time (a wisp, a
// dense marble, a cloud). This is QML pushed with a script, on purpose.
Canvas {
    id: df

    property real freq: 0.9        // noise frequency (higher = finer blobs)
    property int cell: 3           // dither block size in px (the chunk)
    property real bias: 0.0        // tonal bias: + brighter field, - darker
    property real contrast: 2.6    // tonal spread: pushes mid-grey to solid
    property real seed: 1.0        // reroll for a different field
    property color ink: Tokens.ink

    onFreqChanged: requestPaint()
    onBiasChanged: requestPaint()
    onContrastChanged: requestPaint()
    onSeedChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    Component.onCompleted: requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();
        ctx.fillStyle = df.ink;
        var bayer = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
        var s = df.seed;
        function hash(x, y) {
            var n = Math.sin((x + s) * 127.1 + (y + s * 3.7) * 311.7) * 43758.5453;
            return n - Math.floor(n);
        }
        function sm(t) { return t * t * (3 - 2 * t); }
        function vn(x, y) {
            var xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
            var a = hash(xi, yi), b = hash(xi + 1, yi), c = hash(xi, yi + 1), d = hash(xi + 1, yi + 1);
            var u = sm(xf), v = sm(yf);
            return (a * (1 - u) + b * u) * (1 - v) + (c * (1 - u) + d * u) * v;
        }
        function fbm(x, y) {
            var t = 0, am = 0.6, f = 1, sum = 0;
            for (var i = 0; i < 3; i++) { t += am * vn(x * f, y * f); sum += am; f *= 2.1; am *= 0.5; }
            return t / sum;                       // normalised 0..1
        }
        var cols = Math.ceil(df.width / df.cell), rows = Math.ceil(df.height / df.cell);
        var sc = df.freq / 30;
        for (var gy = 0; gy < rows; gy++)
            for (var gx = 0; gx < cols; gx++) {
                var raw = fbm(gx * df.cell * sc, gy * df.cell * sc);
                var n = (raw - 0.5) * df.contrast + 0.5 + df.bias;   // spread mid to solid
                if (n > (bayer[gy % 4][gx % 4] + 0.5) / 16)
                    ctx.fillRect(gx * df.cell, gy * df.cell, df.cell, df.cell);
            }
    }
}
