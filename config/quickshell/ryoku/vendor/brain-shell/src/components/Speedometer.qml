import QtQuick
import "../"

// Arc gauge component.
// Name label above the arc, large percent text in the center,
// detail string (e.g. "11.2 / 16 GB") below the center text.
// When active is false, arc is greyed and "Off" overlays center.
//
// property real size: 1.0  — scale factor. 1.0 = full (120×140). 0.7 = mini.

Item {
    id: root

    property string label:       ""
    property real   percent:     0.0       // 0.0 – 100.0
    property string centerText:  "0%"
    property string bottomText:  ""
    property bool   active:      true
    property color  accentColor: Theme.active
    property real   size:        1.0       // scale factor

    implicitWidth:  Math.round(120 * size)
    implicitHeight: Math.round(140 * size)

    // ── Name label ────────────────────────────────────────────────────────────
    Text {
        id: nameLabel
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              parent.top
        text:           root.label
        font.pixelSize: Math.max(7, Math.round(11 * root.size))
        font.weight:    Font.Medium
        color:          root.active ? Qt.rgba(1,1,1,0.55) : Qt.rgba(1,1,1,0.2)
        Behavior on color { ColorAnimation { duration: 200 } }
    }

    // ── Arc canvas ────────────────────────────────────────────────────────────
    Canvas {
        id: arc
        anchors {
            top:              nameLabel.bottom
            topMargin:        Math.round(6 * root.size)
            horizontalCenter: parent.horizontalCenter
        }
        width:  parent.width
        height: parent.width

        readonly property real cx:        width  / 2
        readonly property real cy:        height / 2
        readonly property real radius:    width  / 2 - Math.round(10 * root.size)
        readonly property real thickness: Math.max(3, Math.round(8 * root.size))

        readonly property real startAngle: 150 * Math.PI / 180
        readonly property real sweepAngle: 245 * Math.PI / 180

        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)

            var sa = arc.startAngle
            var sw = arc.sweepAngle

            // Track
            ctx.beginPath()
            ctx.arc(arc.cx, arc.cy, arc.radius, sa, sa + sw, false)
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.08)
            ctx.lineWidth   = arc.thickness
            ctx.lineCap     = "round"
            ctx.stroke()

            // Fill
            var fillPct = root.active ? Math.max(0, Math.min(1, root.percent / 100)) : 0
            if (fillPct > 0) {
                ctx.beginPath()
                ctx.arc(arc.cx, arc.cy, arc.radius, sa, sa + sw * fillPct, false)
                ctx.strokeStyle = root.active
                    ? Qt.rgba(root.accentColor.r, root.accentColor.g, root.accentColor.b, 1)
                    : Qt.rgba(1, 1, 1, 0.15)
                ctx.lineWidth   = arc.thickness
                ctx.lineCap     = "round"
                ctx.stroke()
            }
        }

        Connections {
            target: root
            function onPercentChanged()      { arc.requestPaint() }
            function onActiveChanged()       { arc.requestPaint() }
            function onAccentColorChanged()  { arc.requestPaint() }
            function onSizeChanged()         { arc.requestPaint() }
        }
    }

    // ── Center text ───────────────────────────────────────────────────────────
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top:              arc.top
        width:  arc.width
        height: arc.height

        Column {
            anchors.centerIn:             parent
            anchors.verticalCenterOffset: Math.round(6 * root.size)
            spacing:  Math.round(2 * root.size)
            opacity:  root.active ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 200 } }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           root.centerText
                font.pixelSize: Math.max(10, Math.round(18 * root.size))
                font.weight:    Font.Bold
                color:          Theme.text
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text:           root.bottomText
                font.pixelSize: Math.max(6, Math.round(9 * root.size))
                color:          Qt.rgba(1, 1, 1, 0.4)
                visible:        root.bottomText !== ""
            }
        }

        // Deactivated overlay
        Text {
            anchors.centerIn:             parent
            anchors.verticalCenterOffset: Math.round(6 * root.size)
            text:           "Off"
            font.pixelSize: Math.max(8, Math.round(13 * root.size))
            font.weight:    Font.Medium
            color:          Qt.rgba(1, 1, 1, 0.25)
            opacity:        root.active ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 200 } }
        }
    }
}
