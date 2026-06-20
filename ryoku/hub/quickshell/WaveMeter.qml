import QtQuick
import "Singletons"

// A Ryoku wave used as a progress meter: the line runs the full width dim, with a
// bright ember crest filled from the left up to `frac` of the width, so the lit
// length reads as progress. It travels gently while visible. The hub-palette
// twin of the shell's WaveMeter.
Item {
    id: root

    property real frac: 0
    property color tint: Theme.ember

    readonly property real amp: 3
    readonly property real wavelength: 12

    implicitHeight: 12

    Behavior on frac { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }

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

            ctx.lineWidth = 2;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";

            ctx.strokeStyle = Qt.alpha(root.tint, 0.18);
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
                ctx.strokeStyle = root.tint;
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
