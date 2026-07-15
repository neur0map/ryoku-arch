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
        x: 2; y: 2
        width: tile.tileW
        height: tile.tileH
        color: Theme.shadow
        visible: tile.lit
        antialiasing: false
    }

    // backlit, not painted: a lit annunciator is a dark tile whose LABEL glows
    // through — a panel of solid colour blocks read as candy, not instruments.
    Rectangle {
        id: face
        width: tile.tileW
        height: tile.tileH
        color: tile.lit ? Qt.rgba(tile.litColor.r, tile.litColor.g, tile.litColor.b, 0.16) : Theme.surfaceLo
        border.width: 1
        border.color: tile.lit ? Qt.alpha(tile.litColor, 0.55) : Theme.lineSoft
        antialiasing: false

        Text {
            anchors.centerIn: parent
            text: tile.label
            color: tile.lit ? Qt.lighter(tile.litColor, 1.25) : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 9
            font.weight: tile.lit ? Font.Bold : Font.DemiBold
            font.letterSpacing: 1.2
        }
        // the lamp strip: a thin lit filament along the base of the glass.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 2
            visible: tile.lit
            color: Qt.alpha(tile.litColor, 0.85)
            antialiasing: false
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
