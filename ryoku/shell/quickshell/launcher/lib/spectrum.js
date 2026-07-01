// Filled smoothed wave path for the now-playing spectrum backdrop. Turns a
// 0..1 levels array into an SVG path string for a Shape/ShapePath: a curve
// through the band tips, closed down the sides to the bottom edge so it fills.
// Pure geometry (no QML, no Date/Math.random), the same quadratic smoothing the
// desktop visualiser draws, so node can exercise it. Consumed by NowPlaying.qml.

// Quadratic-smoothed segments through (xs, ys), left to right.
function svgSmooth(xs, ys) {
    var n = xs.length;
    var s = "";
    for (var k = 0; k < n - 1; k++)
        s += "Q" + xs[k] + " " + ys[k] + " " + ((xs[k] + xs[k + 1]) / 2) + " " + ((ys[k] + ys[k + 1]) / 2) + " ";
    s += "Q" + xs[n - 1] + " " + ys[n - 1] + " " + xs[n - 1] + " " + ys[n - 1] + " ";
    return s;
}

// Build the filled wave path. `levels` are 0..1 band heights, `w`/`h` the draw
// box, `maxFrac` the tallest a band may reach as a fraction of `h`. Returns ""
// when there is nothing to draw (fewer than two bands, or the whole field has
// settled flat) so the caller can hide the wave instead of freezing its last
// frame. `minFrac` keeps a thin resting sliver while there is any energy.
function wavePath(levels, w, h, maxFrac, minFrac) {
    if (!levels || levels.length < 2 || w <= 0 || h <= 0)
        return "";
    var n = levels.length;
    var mx = 0;
    for (var i = 0; i < n; i++)
        if (levels[i] > mx)
            mx = levels[i];
    if (mx < 0.03)
        return "";
    var slotW = w / n;
    var maxH = h * (maxFrac || 0.7);
    var minH = h * (minFrac || 0);
    var xs = [];
    var ys = [];
    for (var j = 0; j < n; j++) {
        var len = Math.max(minH, maxH * levels[j]);
        xs.push(j * slotW + slotW / 2);
        ys.push(h - len);
    }
    return "M0 " + h + " L" + xs[0] + " " + ys[0] + " " + svgSmooth(xs, ys)
        + "L" + w + " " + ys[n - 1] + " L" + w + " " + h + " Z";
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { svgSmooth, wavePath };
}
