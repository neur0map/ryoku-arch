import QtQuick
import "Singletons"

// A row of split-flap cells spelling a word. Characters cascade left-to-right
// (40ms stagger), each cell spinning independently, so a state change reads as
// the departure board updating. Fixed cell width keeps columns registered like
// the real board; `pad` reserves drum width so RUNNING -> OFF doesn't reflow.
Row {
    id: word

    property string text: ""
    property int pad: 0                  // minimum cell count (0 = fit the text)
    property real cellW: 15
    property real cellH: 22
    property real fontPx: 13
    property color ink: Theme.cream
    property color plate: Theme.keyTop
    property color plateLo: Theme.keyBot

    spacing: 2

    readonly property int cells: Math.max(word.pad, word.text.length)
    // staggered feed: each cell learns its character a beat after its neighbor.
    property string fed: ""
    onTextChanged: feeder.restart()
    Component.onCompleted: fed = text
    Timer {
        id: feeder
        interval: 40
        repeat: true
        property int i: 0
        onRunningChanged: if (running) i = 0
        onTriggered: {
            i++;
            word.fed = word.text.substring(0, i) + word.fed.substring(i);
            if (i >= word.cells) {
                word.fed = word.text;
                running = false;
            }
        }
    }

    Repeater {
        model: word.cells
        delegate: FlapCell {
            required property int index
            cellW: word.cellW
            cellH: word.cellH
            fontPx: word.fontPx
            ink: word.ink
            plate: word.plate
            plateLo: word.plateLo
            ch: index < word.fed.length ? word.fed.charAt(index) : " "
        }
    }
}
