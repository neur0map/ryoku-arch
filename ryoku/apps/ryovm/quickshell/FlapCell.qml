import QtQuick
import Ryoku.Ui.Singletons

// One Solari split-flap character cell. Two clipped halves show the current
// character; a change folds the top half down over the seam (forward-only drum
// motion), snapping through like the real mechanism. The plate gradient dies:
// the face is a flat instrument plate (amendment 1), a hairline frame, a black
// seam. The flap itself stays fast and hard: the mechanism is the brand.
Item {
    id: cell

    property string ch: " "
    property real cellW: 15
    property real cellH: 22
    property real fontPx: 13
    property color ink: Tokens.ink
    property bool seam: true

    width: cellW
    height: cellH

    // the character painted on the plates right now (lags ch while flapping).
    property string shown: " "
    property string next: " "
    property bool flapping: false

    Component.onCompleted: shown = ch
    onChChanged: {
        if (ch === shown && !flapping)
            return;
        next = ch;
        if (!flapping)
            flap.restart();
    }

    // plate: a flat instrument face, hard corners, hairline frame.
    Rectangle {
        anchors.fill: parent
        color: Tokens.paperLift
        border.width: Tokens.border
        border.color: Tokens.lineSoft
        antialiasing: false
    }

    // static bottom half: current character until the drop-flap lands.
    FlapHalf {
        t: cell.shown; upper: false
        y: cell.cellH / 2
        cellW: cell.cellW; cellH: cell.cellH; fontPx: cell.fontPx; ink: cell.ink
    }
    // static top half: the NEXT character (revealed as the flap folds away).
    FlapHalf {
        t: cell.flapping ? cell.next : cell.shown; upper: true
        cellW: cell.cellW; cellH: cell.cellH; fontPx: cell.fontPx; ink: cell.ink
    }

    // the moving flap: carries the OLD top half, folds down over the seam.
    Item {
        width: cell.cellW
        height: cell.cellH / 2
        visible: cell.flapping
        transform: Rotation {
            id: fold
            origin.x: cell.cellW / 2
            origin.y: cell.cellH / 2
            axis { x: 1; y: 0; z: 0 }
            angle: 0
        }
        Rectangle { anchors.fill: parent; color: Tokens.paperLift; antialiasing: false }
        FlapHalf {
            t: cell.shown; upper: true
            cellW: cell.cellW; cellH: cell.cellH; fontPx: cell.fontPx; ink: cell.ink
        }
        // the folding face darkens toward black as it turns away.
        Rectangle { anchors.fill: parent; color: Tokens.paper; opacity: fold.angle / -180 }
    }

    // seam line across the middle: the mechanism showing, always. Black.
    Rectangle {
        visible: cell.seam
        y: cell.cellH / 2
        width: cell.cellW
        height: 1
        color: Tokens.paper
        opacity: 0.65
        antialiasing: false
    }

    SequentialAnimation {
        id: flap
        ScriptAction { script: cell.flapping = true }
        NumberAnimation { target: fold; property: "angle"; from: 0; to: -88; duration: 70; easing.type: Easing.InQuad }
        ScriptAction { script: { cell.shown = cell.next; fold.angle = 0; } }
        // the bottom half lands with the plate already swapped: one hard frame,
        // like the real flap slapping the stop pin.
        PauseAnimation { duration: 34 }
        ScriptAction {
            script: {
                cell.flapping = false;
                if (cell.ch !== cell.shown)
                    flap.restart();   // keep spinning until the drum catches up
            }
        }
    }
}
