import QtQuick
import Ryoku.Ui.Singletons

// One backlit-panel annunciator tile, in monochrome grammar (DESIGN 3.4). Three
// states where colour used to fake five:
//   dark  = transparent face, lineSoft border, inkFaint engraved label
//   lit   = tint10 face, lineStrong border, ink label, a 2px ink filament base
//   alarm = the tile inverts to bone, black label, on a 1Hz square-wave blink
// A mostly-dark grid is correct: a quiet panel is a healthy panel.
Item {
    id: tile

    property string label: ""
    property bool lit: false
    property bool warn: false               // alarm: invert + blink while lit
    property real tileW: 54
    property real tileH: 22

    readonly property bool alarm: tile.lit && tile.warn

    width: tileW
    height: tileH

    Rectangle {
        id: face
        anchors.fill: parent
        color: tile.alarm ? Tokens.bone : (tile.lit ? Tokens.tint10 : "transparent")
        border.width: Tokens.border
        border.color: tile.alarm ? Tokens.bone : (tile.lit ? Tokens.lineStrong : Tokens.lineSoft)
        antialiasing: false
        Behavior on color { ColorAnimation { duration: Tokens.snap } }

        Text {
            anchors.centerIn: parent
            text: tile.label
            color: tile.alarm ? Tokens.inkOnBone : (tile.lit ? Tokens.ink : Tokens.inkFaint)
            font.family: Tokens.ui
            font.pixelSize: 9
            font.weight: Font.Medium
            font.letterSpacing: 1.2
            font.capitalization: Font.AllUppercase
        }

        // the lamp filament: a thin lit strip along the base of the glass.
        Rectangle {
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 1 }
            height: 2
            visible: tile.lit && !tile.alarm
            color: Tokens.ink
            antialiasing: false
        }

        // 1Hz square-wave blink for the alarm: opacity toggles, nothing eases.
        Timer {
            running: tile.alarm
            interval: 500
            repeat: true
            onTriggered: face.opacity = face.opacity > 0.5 ? 0.25 : 1
            onRunningChanged: if (!running) face.opacity = 1
        }
    }
}
