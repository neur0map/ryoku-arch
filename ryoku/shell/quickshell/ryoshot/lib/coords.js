function globalToLocal(point, screenX, screenY) {
    return { x: point.x - screenX, y: point.y - screenY };
}

function localToGlobal(point, screenX, screenY) {
    return { x: point.x + screenX, y: point.y + screenY };
}

function intersectRect(globalRect, screenRect) {
    var gx1 = globalRect.x;
    var gy1 = globalRect.y;
    var gx2 = globalRect.x + globalRect.w;
    var gy2 = globalRect.y + globalRect.h;

    var sx1 = screenRect.x;
    var sy1 = screenRect.y;
    var sx2 = screenRect.x + screenRect.width;
    var sy2 = screenRect.y + screenRect.height;

    var ix1 = Math.max(gx1, sx1);
    var iy1 = Math.max(gy1, sy1);
    var ix2 = Math.min(gx2, sx2);
    var iy2 = Math.min(gy2, sy2);

    if (ix2 <= ix1 || iy2 <= iy1) return null;

    return {
        x: ix1 - screenRect.x,
        y: iy1 - screenRect.y,
        w: ix2 - ix1,
        h: iy2 - iy1
    };
}

// Plan a multi-monitor "seam" stitch. Given the global selection rect and the
// screen rects (logical global px) it may span, return the composite canvas size
// and, per intersecting screen, the local grab rect plus the offset to composite
// it at. Everything is logical: grabbing each slice at its local logical size and
// compositing here keeps mixed-scale monitors aligned. Grabbing at device pixels
// instead makes a HiDPI slice oversized and shifts the seam, which is why a
// span across differently-scaled monitors came out broken.
function stitchPlan(globalSel, screens) {
    var slices = [];
    for (var i = 0; i < screens.length; i++) {
        var inter = intersectRect(globalSel, screens[i]);
        if (!inter) continue;
        slices.push({
            screen: i,
            local: inter,
            ox: Math.round(screens[i].x + inter.x - globalSel.x),
            oy: Math.round(screens[i].y + inter.y - globalSel.y)
        });
    }
    return { canvas: { w: Math.round(globalSel.w), h: Math.round(globalSel.h) }, slices: slices };
}

function rectFromPoints(a, b) {
    var x = Math.min(a.x, b.x);
    var y = Math.min(a.y, b.y);
    return { x: x, y: y, w: Math.abs(b.x - a.x), h: Math.abs(b.y - a.y) };
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { globalToLocal, localToGlobal, intersectRect, rectFromPoints, stitchPlan };
}
