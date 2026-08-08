import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: rootMod
    required property var root

    visible: implicitWidth > 0.5
    implicitWidth: root.modMemory ? row.implicitWidth + 18 : 0
    implicitHeight: 28
    opacity: root.modMemory ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    readonly property int percent: root.systemMemPercent
    readonly property real usedGiB: root.systemMemUsedGiB
    readonly property real totalGiB: root.systemMemTotalGiB
    readonly property string usedLabel: String(Math.round(usedGiB)).padStart(2, '0') + "G"
    readonly property string tooltipText: usedGiB.toFixed(1) + "/" + totalGiB.toFixed(0) + "G"

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
        anchors.horizontalCenterOffset: root.compactMemory ? -1 : 0
        spacing: root.compactMemory ? 4 : 5

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: !root.compactMemory
            text: "MEM"
            color: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.6)
            font.family: root.mono
            font.pixelSize: 12
            font.letterSpacing: 0.5
        }

        Canvas {
            id: ring
            visible: !root.compactMemory
            width: 16
            height: 16
            anchors.verticalCenter: parent.verticalCenter

            property color tint: root.seal
            onTintChanged: requestPaint()

            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                var cx = width / 2
                var cy = height / 2
                var r = (width / 2) - 1.5
                var ratio = rootMod.totalGiB > 0 ? rootMod.usedGiB / rootMod.totalGiB : 0
                var start = -Math.PI / 2
                var end = start + (2 * Math.PI * ratio)

                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, 2 * Math.PI)
                ctx.strokeStyle = Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.18)
                ctx.lineWidth = 2
                ctx.lineCap = "round"
                ctx.stroke()

                if (ratio > 0) {
                    ctx.beginPath()
                    ctx.arc(cx, cy, r, start, end)
                    ctx.strokeStyle = tint
                    ctx.lineWidth = 2
                    ctx.lineCap = "round"
                    ctx.stroke()
                }
            }

            Component.onCompleted: requestPaint()
            Connections {
                target: rootMod
                function onUsedGiBChanged() { ring.requestPaint() }
            }
        }

        Row {
            visible: !root.compactMemory
            spacing: 0
            anchors.verticalCenter: parent.verticalCenter

            UiText {
                text: rootMod.usedLabel
                color: root.seal
                font.family: root.mono
                font.pixelSize: 12
            }
        }

        Item {
            id: compactMemGlyph
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactMemory
            width: 16
            height: 16

            Canvas {
                id: compactMemRing
                anchors.fill: parent

                property color tint: root.seal
                property color base: root.ink
                onTintChanged: requestPaint()
                onBaseChanged: requestPaint()

                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0, 0, width, height)
                    var cx = width / 2
                    var cy = height / 2
                    var r = (width / 2) - 1.5
                    var ratio = Math.max(0, Math.min(1, rootMod.percent / 100))
                    var start = -Math.PI / 2
                    var end = start + Math.PI * 2 * ratio

                    ctx.lineWidth = 1.7
                    ctx.lineCap = "round"

                    ctx.beginPath()
                    ctx.arc(cx, cy, r, 0, Math.PI * 2)
                    ctx.strokeStyle = Qt.rgba(base.r, base.g, base.b, 0.18)
                    ctx.stroke()

                    if (ratio > 0) {
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, start, end)
                        ctx.strokeStyle = tint
                        ctx.stroke()
                    }
                }

                Component.onCompleted: requestPaint()
                Connections {
                    target: rootMod
                    function onPercentChanged() { compactMemRing.requestPaint() }
                }
            }
        }

        UiText {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.compactMemory
            text: rootMod.usedLabel
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
        onClicked: { tip.hide(); root.memVisible = !root.memVisible }
    }
}
