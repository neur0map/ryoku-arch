pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// Ryoku wave used as a meter: dim line full-width, bright (brand) crest fills
// left to `frac` -- lit length = value. held static; its idle Canvas ripple
// repainted ~25fps forever and leaked memory. RAM + disk on the system card.
Item {
    id: root

    property real s: 1
    property real frac: 0

    readonly property real amp: 2.2 * s
    readonly property real wavelength: 8 * s

    implicitHeight: 9 * s

    Behavior on frac { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }

    Canvas {
        id: canvas
        anchors.fill: parent

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const mid = height / 2;
            const k = 6.28318 / root.wavelength;
            const fill = Math.max(0, Math.min(1, root.frac)) * w;

            ctx.lineWidth = 2 * root.s;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            ctx.strokeStyle = Qt.alpha(Theme.primary, 0.18);
            ctx.beginPath();
            for (let x = 0; x <= w; x += 1.5) {
                const y = mid + root.amp * Math.sin(x * k);
                if (x === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();

            if (fill > 1) {
                ctx.strokeStyle = Theme.primary;
                ctx.beginPath();
                for (let x = 0; x <= fill; x += 1.5) {
                    const y = mid + root.amp * Math.sin(x * k);
                    if (x === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }

        Connections {
            target: root
            function onFracChanged() { canvas.requestPaint(); }
        }
    }
}
