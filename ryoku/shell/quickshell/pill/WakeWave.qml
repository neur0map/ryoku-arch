pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

/**
 * Ryoku's island wake: when the island opens, one orange wave streaks left to
 * right along the base and runs clean off the right edge -- a bright comet crest
 * with a fading trail, no fade-in-place. The house flourish that makes opening
 * feel alive, standing in for the inherited soul-bead's entrance. One-shot per
 * open; idle cost is nil (it only animates while crossing).
 */
Item {
    id: root

    property real s: 1
    property bool live: false

    readonly property real amp: 4 * s
    readonly property real wavelength: 12 * s
    readonly property real trail: 105 * s

    // 0..1 carries the crest from the left edge to fully off the right edge.
    property real sweep: 0
    readonly property bool running: sweep > 0 && sweep < 1

    onLiveChanged: {
        if (live) {
            play();
        } else {
            anim.stop();
            sweep = 0;
            canvas.requestPaint();
        }
    }

    function play() {
        sweep = 0;
        anim.restart();
    }

    NumberAnimation {
        id: anim
        target: root
        property: "sweep"
        from: 0
        to: 1
        duration: 1150
        easing.type: Easing.InOutSine
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        property real phase: 0

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const w = width;
            const mid = height * 0.82;
            const k = 6.28318 / root.wavelength;
            const front = root.sweep * (w + root.trail);
            const tail = front - root.trail;
            const a = Math.max(0, tail);
            const b = Math.min(w, front);
            if (b - a < 1)
                return;

            const grad = ctx.createLinearGradient(tail, 0, front, 0);
            grad.addColorStop(0, Qt.alpha(Theme.brand, 0));
            grad.addColorStop(1, Theme.brand);

            ctx.strokeStyle = grad;
            ctx.lineWidth = 2.5 * root.s;
            ctx.lineCap = "round";
            ctx.lineJoin = "round";
            ctx.beginPath();
            for (let x = a; x <= b; x += 1.5) {
                const y = mid + root.amp * Math.sin(x * k + phase);
                if (x === a)
                    ctx.moveTo(x, y);
                else
                    ctx.lineTo(x, y);
            }
            ctx.stroke();

            if (front <= w) {
                const cy = mid + root.amp * Math.sin(front * k + phase);
                ctx.beginPath();
                ctx.arc(front, cy, 4 * root.s, 0, 6.28318);
                ctx.fillStyle = Theme.brand;
                ctx.fill();
            }
        }

        Timer {
            interval: 33
            running: root.running
            repeat: true
            onTriggered: {
                canvas.phase = (canvas.phase + 0.16) % 6.28318;
                canvas.requestPaint();
            }
        }

        Connections {
            target: root
            function onSweepChanged() { canvas.requestPaint(); }
        }
    }
}
