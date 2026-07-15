import QtQuick
import "Singletons"

// One Apollo-panel annunciator tile: a small hard rectangle that is either
// unlit (dark, engraved label) or lit (solid color, hard shadow). Warning tiles
// blink a 1Hz square wave — no easing, machines don't fade. Mostly-dark grids
// are correct: a quiet panel is a healthy panel.
Item {
    id: tile

    property string label: ""
    property bool lit: false
    property bool warn: false               // blink while lit
    property color litColor: Theme.ok
    property real tileW: 52
    property real tileH: 22

    width: tileW
    height: tileH

    // hard shadow only while lit: a lit tile is raised, an unlit one is flush.
    Rectangle {
        x: 3; y: 3
        width: tile.tileW
        height: tile.tileH
        color: Theme.shadow
        visible: tile.lit
        antialiasing: false
    }

    Rectangle {
        id: face
        width: tile.tileW
        height: tile.tileH
        color: tile.lit ? tile.litColor : Theme.surfaceLo
        border.width: 1
        border.color: tile.lit ? Qt.darker(tile.litColor, 1.35) : Theme.lineSoft
        antialiasing: false

        Text {
            anchors.centerIn: parent
            text: tile.label
            color: tile.lit ? Theme.onAccent : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 9
            font.weight: Font.DemiBold
            font.letterSpacing: 1.2
        }

        // 1Hz square-wave blink for warnings: visible toggles, nothing eases.
        Timer {
            running: tile.lit && tile.warn
            interval: 500
            repeat: true
            onTriggered: face.opacity = face.opacity > 0.5 ? 0.25 : 1
            onRunningChanged: if (!running) face.opacity = 1
        }
    }
}
