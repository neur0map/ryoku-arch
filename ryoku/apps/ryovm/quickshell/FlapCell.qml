import QtQuick
import "Singletons"

// One Solari split-flap character cell. Two clipped halves show the current
// character; a change folds the top half down over the seam (forward-only drum
// motion), snapping through like the real mechanism. Mechanical rule: the flap
// itself is fast and hard — spatial easing is for spatial moves, not machines.
Item {
    id: cell

    property string ch: " "
    property real cellW: 15
    property real cellH: 22
    property real fontPx: 13
    property color ink: Theme.cream
    property color plate: Theme.keyTop
    property color plateLo: Theme.keyBot
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

    // plate background: a keycap gradient, hard corners.
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: cell.plate }
            GradientStop { position: 1.0; color: cell.plateLo }
        }
        border.width: 1
        border.color: Theme.lineSoft
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
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: cell.plate }
                GradientStop { position: 1.0; color: Qt.darker(cell.plate, 1.15) }
            }
            antialiasing: false
        }
        FlapHalf {
            t: cell.shown; upper: true
            cellW: cell.cellW; cellH: cell.cellH; fontPx: cell.fontPx; ink: cell.ink
        }
        Rectangle { anchors.fill: parent; color: Theme.shadow; opacity: fold.angle / -180 }
    }

    // seam line across the middle: the mechanism showing, always.
    Rectangle {
        visible: cell.seam
        y: cell.cellH / 2
        width: cell.cellW
        height: 1
        color: Theme.shadow
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
