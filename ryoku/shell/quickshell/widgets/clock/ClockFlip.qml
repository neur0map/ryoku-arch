pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// flip face: split-flap cards, one per digit. fold edge-on, swap, fold back
// when the digit changes. dark cards, centre seam, faint accent edge to tie
// the palette. colon carries the accent. hours are always two cards so the
// look holds in 12h and 24h.
Item {
    id: face

    readonly property var t: Clk.parts(Now.date, Config.clock24h)
    readonly property color accent: Clk.pickAccent(Config.clockAccent, Wallust.accent, Theme.brand, Theme.ink)
    readonly property real s: Config.clockScale
    readonly property real ch: Math.round(104 * s)
    readonly property real cw: Math.round(face.ch * 0.72)
    readonly property string hh: Config.clock24h ? face.t.hh : Clk.pad2(face.t.h12)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    component FlipDigit: Item {
        id: fd
        property string value: "0"
        property string shown: "0"
        implicitWidth: face.cw
        implicitHeight: face.ch

        onValueChanged: if (fd.value !== fd.shown) flip.restart()
        Component.onCompleted: fd.shown = fd.value

        Rectangle {
            id: card
            anchors.fill: parent
            radius: Math.round(face.ch * 0.16)
            color: Qt.rgba(0, 0, 0, 0.55)
            border.width: Math.max(1, Math.round(face.s))
            border.color: Qt.rgba(face.accent.r, face.accent.g, face.accent.b, 0.24)
            antialiasing: true
            transform: Rotation {
                id: rot
                origin.x: card.width / 2
                origin.y: card.height / 2
                axis { x: 1; y: 0; z: 0 }
                angle: 0
            }

            Text {
                anchors.centerIn: parent
                text: fd.shown
                color: Theme.ink
                font.family: Theme.mono
                font.pixelSize: Math.round(face.ch * 0.64)
                font.weight: Font.Bold
            }

            // fold seam across the middle.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: Math.max(1, Math.round(2 * face.s))
                color: Qt.rgba(0, 0, 0, 0.4)
            }
        }

        SequentialAnimation {
            id: flip
            NumberAnimation { target: rot; property: "angle"; from: 0; to: 88; duration: 120; easing.type: Easing.InQuad }
            ScriptAction { script: fd.shown = fd.value }
            NumberAnimation { target: rot; property: "angle"; from: -88; to: 0; duration: 150; easing.type: Easing.OutQuad }
        }
    }

    Row {
        id: row
        spacing: Math.round(7 * face.s)

        FlipDigit { value: face.hh.charAt(0) }
        FlipDigit { value: face.hh.charAt(1) }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            color: face.accent
            font.family: Theme.mono
            font.pixelSize: Math.round(face.ch * 0.5)
            font.weight: Font.Bold
            SequentialAnimation on opacity {
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.3; duration: 620; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.3; to: 1; duration: 620; easing.type: Easing.InOutSine }
            }
        }

        FlipDigit { value: face.t.mm.charAt(0) }
        FlipDigit { value: face.t.mm.charAt(1) }

        Text {
            visible: Config.clockSeconds
            anchors.verticalCenter: parent.verticalCenter
            text: ":"
            color: face.accent
            font.family: Theme.mono
            font.pixelSize: Math.round(face.ch * 0.5)
            font.weight: Font.Bold
        }
        FlipDigit { visible: Config.clockSeconds; value: face.t.ss.charAt(0) }
        FlipDigit { visible: Config.clockSeconds; value: face.t.ss.charAt(1) }
    }
}
