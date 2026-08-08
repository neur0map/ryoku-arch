import QtQuick
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "Singletons"

// The ambient frame the whole walkthrough sits in: the threshold art (marble
// columns woven with torii receding to the red sun -- art manufactures its own
// accent, the one place colour lives), a black wash to seat it on the paper, an
// edge vignette that melts it into the window edge, and registration ticks. The
// art is generated at dev time and committed (art/welcome-bg.png); the running
// target has no generation dependency. Content scrims live in Welcome.qml so
// each step can tune how much art shows through.
Item {
    id: backdrop

    Image {
        id: art
        anchors.fill: parent
        source: Qt.resolvedUrl("art/welcome-bg.png")
        fillMode: Image.PreserveAspectCrop
        cache: true
        asynchronous: true
        smooth: true
        opacity: status === Image.Ready ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.swap; easing.type: Motion.ease } }
    }

    // seat the plate on the paper: a faint pure-black wash over all.
    Rectangle {
        anchors.fill: parent
        color: Tokens.paper
        opacity: 0.18
    }

    // edge vignette: darken the corners so content holds the eye and the plate
    // melts into the paper at the window edge.
    Canvas {
        anchors.fill: parent
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            let ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            let r = Math.max(width, height) * 0.86;
            let g = ctx.createRadialGradient(width * 0.5, height * 0.46, r * 0.34, width * 0.5, height * 0.46, r);
            g.addColorStop(0, "rgba(0,0,0,0)");
            g.addColorStop(1, "rgba(0,0,0,0.42)");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, width, height);
        }
    }

    // registration ticks bracketing the sheet, the house corner vocabulary.
    Ticks {
        anchors.margins: 16
        arm: 22
        color: Tokens.line
    }
}
