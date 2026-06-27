pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// Ryoku wave as a meter. dim line full-width, bright (brand) crest filled from
// the left up to `frac` of the width: lit length = the value. travels gently
// while visible. used for RAM + disk readouts on the system card. set `frac`
// (0..1) and a width.
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
        property real phase: 0

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

            ctx.strokeStyle = Qt.alpha(Theme.brand, 0.18);
            ctx.beginPath();
            for (let x = 0; x <= w; x += 1.5) {
                const y = mid + root.amp * Math.sin(x * k + phase);
                if (x === 0)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();

            if (fill > 1) {
                ctx.strokeStyle = Theme.brand;
                ctx.beginPath();
                for (let x = 0; x <= fill; x += 1.5) {
                    const y = mid + root.amp * Math.sin(x * k + phase);
                    if (x === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }

        Timer {
            interval: 40
            running: root.visible
            repeat: true
            onTriggered: {
                canvas.phase = (canvas.phase + 0.09) % 6.28318;
                canvas.requestPaint();
            }
        }

        Connections {
            target: root
            function onFracChanged() { canvas.requestPaint(); }
        }
    }
}
