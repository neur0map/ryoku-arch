import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import "../colors" as ColorsModule

PanelWindow {
    id: musicVis

    property bool anchorBottom: true
    property bool flipped: !anchorBottom

    implicitHeight: 200
    visible: false
    color: "transparent"

    WlrLayershell.layer: WlrLayer.Bottom
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        left: true
        right: true
        bottom: anchorBottom
        top: !anchorBottom
    }

    Process {
        id: cavaProc
        running: musicVis.visible

        command: ["sh", "-c", `
            cava -p /dev/stdin <<EOF
[general]
bars = 20
framerate = 30
autosens = 1

[input]
method = pulse

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 1000
bar_delimiter = 59

[smoothing]
monstercat = 1.5
waves = 0
gravity = 100
noise_reduction = 0.20
EOF
        `]

        stdout: SplitParser {
            onRead: data => {
                let newPoints = data.split(";")
                    .map(p => parseFloat(p.trim()) / 1000)
                    .filter(p => !isNaN(p))

                let smoothFactor = 0.3

                if (canvas.cavaData.length === 0 ||
                    canvas.cavaData.length !== newPoints.length) {
                    canvas.cavaData = newPoints
                } else {
                    let smoothed = []
                    for (let i = 0; i < newPoints.length; i++) {
                        let oldVal = canvas.cavaData[i]
                        let newVal = newPoints[i]
                        smoothed.push(oldVal + (newVal - oldVal) * smoothFactor)
                    }
                    canvas.cavaData = smoothed
                }

                canvas.requestPaint()
            }
        }
    }

    Canvas {
        id: canvas
        anchors.fill: parent
        property var cavaData: []

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            drawMountainWave(ctx, cavaData, true)
            drawMountainWave(ctx, cavaData, false)
        }

        function drawMountainWave(ctx, data, isShadow) {
            if (data.length < 2) return

            var gradient = ctx.createLinearGradient(0, 0, width, height)

            gradient.addColorStop(0.0, ColorsModule.Colors.primary)
            gradient.addColorStop(0.5, ColorsModule.Colors.tertiary)
            gradient.addColorStop(1.0, ColorsModule.Colors.secondary)

            ctx.beginPath()

            if (isShadow) {
                ctx.globalAlpha = 0.25
                ctx.save()
                ctx.translate(0, flipped ? 10 : -10)
                ctx.scale(1.02, 1.05)
            } else {
                ctx.globalAlpha = 1.0
            }

            ctx.fillStyle = gradient

            // For flipped: base is at top (y=0), waves grow downward
            // For normal: base is at bottom (y=height), waves grow upward
            var baseY = flipped ? 0 : height

            ctx.moveTo(0, baseY)

            var startY = flipped
                ? (data[0] * height)
                : height - (data[0] * height)
            ctx.lineTo(0, startY)

            var barWidth = width / (data.length - 1)

            for (var i = 0; i < data.length - 1; i++) {
                var xCurr = i * barWidth
                var yCurr = flipped
                    ? (data[i] * height)
                    : height - (data[i] * height)

                var xNext = (i + 1) * barWidth
                var yNext = flipped
                    ? (data[i + 1] * height)
                    : height - (data[i + 1] * height)

                var xMid = (xCurr + xNext) / 2
                var yMid = (yCurr + yNext) / 2

                ctx.quadraticCurveTo(xCurr, yCurr, xMid, yMid)
            }

            var lastX = (data.length - 1) * barWidth
            var lastY = flipped
                ? (data[data.length - 1] * height)
                : height - (data[data.length - 1] * height)

            ctx.lineTo(lastX, lastY)
            ctx.lineTo(width, baseY)
            ctx.closePath()
            ctx.fill()

            if (isShadow)
                ctx.restore()
        }
    }
}