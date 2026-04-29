import QtQuick
import "../"

Canvas {
    id: root
    anchors.fill: parent

    // These are set by TopBar.qml with the real clamped widths.
    // They default to the Theme constraints so the shape is never empty.
    property int leftWidth:   Theme.lNotchMinWidth
    property int centerWidth: Theme.cNotchMinWidth
    property int rightWidth:  Theme.rNotchMinWidth

    property int notchHeight:     Theme.notchHeight
    property int radius:          Theme.notchRadius
    property int topBorderWidth:  Theme.borderWidth
    property color color:         Theme.background

    onWidthChanged:       requestPaint()
    onHeightChanged:      requestPaint()
    onLeftWidthChanged:   requestPaint()
    onCenterWidthChanged: requestPaint()
    onRightWidthChanged:  requestPaint()
    onColorChanged:       requestPaint()

    onPaint: {
        var ctx = getContext("2d");
        ctx.reset();

        var leftW   = root.leftWidth
        var centerW = root.centerWidth
        var rightW  = root.rightWidth

        var r = root.radius
        var h = root.notchHeight
        var b = root.topBorderWidth
        var w = width

        // Calculated positions
        var centerStart = (w / 2) - (centerW / 2)
        var centerEnd   = (w / 2) + (centerW / 2)
        var rightStart  = w - rightW

        ctx.beginPath();
        ctx.fillStyle = root.color;

        // ============================
        // 1. LEFT NOTCH
        // ============================
        ctx.moveTo(0, h);
        ctx.lineTo(leftW - r, h);
        ctx.arcTo(leftW, h, leftW, h - r, r);
        ctx.lineTo(leftW, b + r);
        ctx.arcTo(leftW, b, leftW + r, b, r);

        // ============================
        // 2. GAP 1 (Left → Center)
        // ============================
        ctx.lineTo(centerStart - r, b);

        // ============================
        // 3. CENTER NOTCH
        // ============================
        ctx.arcTo(centerStart, b, centerStart, b + r, r);
        ctx.lineTo(centerStart, h - r);
        ctx.arcTo(centerStart, h, centerStart + r, h, r);
        ctx.lineTo(centerEnd - r, h);
        ctx.arcTo(centerEnd, h, centerEnd, h - r, r);
        ctx.lineTo(centerEnd, b + r);
        ctx.arcTo(centerEnd, b, centerEnd + r, b, r);

        // ============================
        // 4. GAP 2 (Center → Right)
        // ============================
        ctx.lineTo(rightStart - r, b);

        // ============================
        // 5. RIGHT NOTCH
        // ============================
        ctx.arcTo(rightStart, b, rightStart, b + r, r);
        ctx.lineTo(rightStart, h - r);
        ctx.arcTo(rightStart, h, rightStart + r, h, r);
        ctx.lineTo(w, h);

        // ============================
        // 6. CLOSE LOOP
        // ============================
        ctx.lineTo(w, 0);
        ctx.lineTo(0, 0);
        ctx.lineTo(0, h);

        ctx.fill();
    }
}
