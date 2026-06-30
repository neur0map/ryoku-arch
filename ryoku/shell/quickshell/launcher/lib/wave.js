// Sample points for the now-playing wavy seekbar: the filled portion of the
// progress bar is a moving sine wave while playing, flat when paused. The Canvas
// calls samplePoints() each frame with an advancing phase. Pure math so the curve
// is node-tested; the QML side only draws the returned points.

// Return [{x, y}] across width `w`, centered at `cy`, with the given amplitude,
// number of full waves across the width, and phase (radians). `steps` controls
// resolution.
function samplePoints(w, cy, amplitude, waves, phase, steps) {
    steps = steps && steps > 0 ? steps : 32;
    var pts = [];
    for (var i = 0; i <= steps; i++) {
        var x = (w * i) / steps;
        var theta = waves * 2 * Math.PI * (i / steps) + phase;
        pts.push({ x: x, y: cy + amplitude * Math.sin(theta) });
    }
    return pts;
}

// Phase advance for a timestamp (ms), matching inir's Date.now()/400 cadence, so
// the wave drifts at a steady, gentle speed independent of frame rate.
function phaseFor(nowMs) {
    return nowMs / 400;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { samplePoints, phaseFor };
}
