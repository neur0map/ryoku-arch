import QtQuick

// alignment grid shown during a widget drag: faint minor lines on the snap
// cell, brighter ones every few cells. fades in on pick-up, out on drop.
// purely visual (no input); the host flips the layer interactive during a
// drag. one Canvas pass, so a 4K desktop stays cheap.
Item {
    id: grid

    property bool active: false
    property real gridSize: 32
    property int majorEvery: 4

    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    Canvas {
        id: canvas
        anchors.fill: parent
        renderStrategy: Canvas.Cooperative

        onPaint: {
            const ctx = getContext("2d");
            const g = grid.gridSize;
            const gm = g * grid.majorEvery;
            ctx.reset();
            ctx.clearRect(0, 0, width, height);

            ctx.lineWidth = 1;
            ctx.strokeStyle = "rgba(245,243,255,0.05)";
            ctx.beginPath();
            for (let x = g; x < width; x += g) { ctx.moveTo(x + 0.5, 0); ctx.lineTo(x + 0.5, height); }
            for (let y = g; y < height; y += g) { ctx.moveTo(0, y + 0.5); ctx.lineTo(width, y + 0.5); }
            ctx.stroke();

            ctx.strokeStyle = "rgba(245,243,255,0.11)";
            ctx.beginPath();
            for (let xm = gm; xm < width; xm += gm) { ctx.moveTo(xm + 0.5, 0); ctx.lineTo(xm + 0.5, height); }
            for (let ym = gm; ym < height; ym += gm) { ctx.moveTo(0, ym + 0.5); ctx.lineTo(width, ym + 0.5); }
            ctx.stroke();
        }

        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        Component.onCompleted: requestPaint()
    }
}
