import QtQuick

// RYOKU: seamless top-bar shape. Geometry adapted from Brain_Shell's
// SeamlessBarShape (MIT, Copyright (c) 2026 Venkat Saahit Kamu / Brainitech) —
// visual/layout inspiration only, no third-party code or runtime is used.
//
// ONE continuous shape so the bar and frame read as a single rounded body:
//   • a thin full-width top strip (topBorderWidth) that drops into three notches
//     at the clusters, each joining the strip with concave fillets and convex
//     rounded bottoms (radius);
//   • the two top screen corners rounded by outerRadius;
//   • the two bottom corners where the bar narrows into the thin side borders
//     rounded by innerRadius — these are the content area's top corners, and
//     match the frame's rounded bottom corners so the whole frame is uniform.
// The side borders below (drawn by the blob frame) continue from the stubs.
Canvas {
    id: root

    property real leftWidth: 180
    property real centerWidth: 300
    property real rightWidth: 180

    property real notchHeight: 40 // depth of a notch (the bar height)
    property real radius: 15 // notch corner radius (concave top + convex bottom)
    property real topBorderWidth: 6 // thin strip + side-border thickness
    property real outerRadius: 17 // outer screen corners (frame match)
    property real innerRadius: 17 // inner corners where the bar meets the side borders
    property color color: "black"

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onLeftWidthChanged: requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged: requestPaint()
    onNotchHeightChanged: requestPaint()
    onRadiusChanged: requestPaint()
    onTopBorderWidthChanged: requestPaint()
    onOuterRadiusChanged: requestPaint()
    onInnerRadiusChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();

        const r = root.radius;
        const h = root.notchHeight;
        const b = root.topBorderWidth;
        const w = width;
        const R = Math.min(root.outerRadius, root.leftWidth, root.rightWidth, h);
        // Inner corner radius (bar → side border). Kept within the notch so the
        // fillet never runs past the notch content.
        const Ri = Math.min(root.innerRadius, root.leftWidth - b - r, root.rightWidth - b - r);
        const ck = R * 0.4477; // cubic control offset (1 − kappa) → circular outer corner

        const cS = (w - root.centerWidth) / 2;
        const cE = (w + root.centerWidth) / 2;
        const rS = w - root.rightWidth;
        const lE = root.leftWidth;

        ctx.beginPath();
        ctx.fillStyle = root.color;

        // Left side-border stub → inner fillet (rounds the content's top-left).
        ctx.moveTo(0, h + Ri);
        ctx.lineTo(b, h + Ri);
        ctx.arcTo(b, h, b + Ri, h, Ri);

        // Left notch.
        ctx.lineTo(lE - r, h);
        ctx.arcTo(lE, h, lE, h - r, r); // convex bottom-right
        ctx.lineTo(lE, b + r);
        ctx.arcTo(lE, b, lE + r, b, r); // concave top, joins strip

        // Strip → center notch.
        ctx.lineTo(cS - r, b);
        ctx.arcTo(cS, b, cS, b + r, r); // concave top-left
        ctx.lineTo(cS, h - r);
        ctx.arcTo(cS, h, cS + r, h, r); // convex bottom-left
        ctx.lineTo(cE - r, h);
        ctx.arcTo(cE, h, cE, h - r, r); // convex bottom-right
        ctx.lineTo(cE, b + r);
        ctx.arcTo(cE, b, cE + r, b, r); // concave top-right

        // Strip → right notch.
        ctx.lineTo(rS - r, b);
        ctx.arcTo(rS, b, rS, b + r, r); // concave top-left
        ctx.lineTo(rS, h - r);
        ctx.arcTo(rS, h, rS + r, h, r); // convex bottom-left

        // Right inner fillet (rounds the content's top-right) → side-border stub.
        ctx.lineTo(w - b - Ri, h);
        ctx.arcTo(w - b, h, w - b, h + Ri, Ri);
        ctx.lineTo(w, h + Ri);

        // Up the right edge, around the top, rounding the two screen corners.
        ctx.lineTo(w, R);
        ctx.bezierCurveTo(w, ck, w - ck, 0, w - R, 0); // top-right outer corner
        ctx.lineTo(R, 0);
        ctx.bezierCurveTo(ck, 0, 0, ck, 0, R); // top-left outer corner
        ctx.lineTo(0, h + Ri);

        ctx.fill();
    }
}
