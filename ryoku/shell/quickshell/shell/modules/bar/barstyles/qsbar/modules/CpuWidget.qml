import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    visible: implicitWidth > 0.5
    implicitWidth: root.modCpu ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modCpu ? 1 : 0
    Behavior on opacity      { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property int percent: root.systemCpuPercent
    readonly property var history: root.systemCpuHistory
    readonly property int maxSamples: 30
    readonly property string tooltipText: percent + "%"

    Rectangle {
        x: 0; anchors.verticalCenter: parent.verticalCenter
        width: Math.round(row.width) + 18
        height: root.pillH
        radius: root.pillRadius
        color: root.pill
        border.color: root.pillBorder
        border.width: root.pillBorderW
        PillShadow { theme: root }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: root.compactCpu ? 4 : 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactCpu
            text: "CPU"
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }

        Canvas {
            id: wave
            visible: !root.compactCpu
            width: 36
            height: 14
            anchors.verticalCenter: parent.verticalCenter

            property color tint: root.seal
            onTintChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var h = rootMod.history
                if (h.length < 2) return

                var maxV = 0.25
                for (var n = 0; n < h.length; n++) {
                    if (h[n] > maxV) maxV = h[n]
                }
                maxV = Math.min(1, Math.max(0.25, maxV * 1.15))

                var pts = []
                for (var i = 0; i < h.length; i++) {
                    var x = (i / (maxSamples - 1)) * width
                    var y = height - (h[i] / maxV) * height
                    pts.push({ x: x, y: y })
                }

                // fill
                ctx.beginPath()
                ctx.moveTo(pts[0].x, height)
                ctx.lineTo(pts[0].x, pts[0].y)
                for (var j = 1; j < pts.length; j++) {
                    var cx = (pts[j-1].x + pts[j].x) / 2
                    ctx.bezierCurveTo(cx, pts[j-1].y, cx, pts[j].y, pts[j].x, pts[j].y)
                }
                ctx.lineTo(pts[pts.length-1].x, height)
                ctx.closePath()
                ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.12)
                ctx.fill()

                // stroke
                ctx.beginPath()
                ctx.moveTo(pts[0].x, pts[0].y)
                for (var k = 1; k < pts.length; k++) {
                    var mx = (pts[k-1].x + pts[k].x) / 2
                    ctx.bezierCurveTo(mx, pts[k-1].y, mx, pts[k].y, pts[k].x, pts[k].y)
                }
                ctx.strokeStyle = tint
                ctx.lineWidth = 1.5
                ctx.lineCap = "round"
                ctx.lineJoin = "round"
                ctx.stroke()
            }

            Component.onCompleted: requestPaint()
            Connections {
                target: rootMod
                function onHistoryChanged() { wave.requestPaint() }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactCpu
            text: String(Math.min(100, rootMod.percent)).padStart(2, '0') + "%"
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
        }

        IconText {
            id: compactCpuGlyph
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactCpu
            text: "planner_review"
            color: root.seal
            font.pixelSize: 15
            font.weight: Font.DemiBold
            fill: 1
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactCpu
            text: String(Math.min(100, rootMod.percent)).padStart(2, '0') + "%"
            color: root.seal
            font.family: root.mono
            font.pixelSize: 12
        }
    }

    TooltipMixin { id: tip; root: rootMod.root; owner: rootMod; text: rootMod.tooltipText }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: tip.show()
        onExited: { tip.hide() }
        onClicked: { tip.hide(); root.cpuVisible = !root.cpuVisible }
    }
}
