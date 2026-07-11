pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// The ambient frame the whole walkthrough sits in: the fal.ai Greek-noir threshold
// art (marble columns woven with torii receding to the red sun), a warm-black tint
// to marry it to the canvas, an edge vignette, and editorial corner ticks. The art
// is generated at dev time and committed (art/welcome-bg.png); the running target
// has no generation dependency. Content scrims live in Welcome.qml so each step can
// tune how much art shows through.
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
        Behavior on opacity { NumberAnimation { duration: Theme.slow; easing.type: Theme.ease } }
    }

    // marry the plate to the near-black canvas: a faint warm-black wash over all.
    Rectangle {
        anchors.fill: parent
        color: Theme.bgBot
        opacity: 0.18
    }

    // edge vignette: darken the corners so content holds the eye and the plate melts
    // into the window edge.
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

    // editorial corner ticks: a light registration frame around the window.
    Repeater {
        model: 4
        Item {
            id: tick
            required property int index
            readonly property bool onLeft: index % 2 === 0
            readonly property bool onTop: index < 2
            readonly property real len: 22
            width: len
            height: len
            anchors.left: onLeft ? parent.left : undefined
            anchors.right: onLeft ? undefined : parent.right
            anchors.top: onTop ? parent.top : undefined
            anchors.bottom: onTop ? undefined : parent.bottom
            anchors.margins: 16

            Rectangle {
                width: tick.len
                height: 1.5
                color: Theme.line
                anchors.top: tick.onTop ? parent.top : undefined
                anchors.bottom: tick.onTop ? undefined : parent.bottom
                anchors.left: tick.onLeft ? parent.left : undefined
                anchors.right: tick.onLeft ? undefined : parent.right
            }
            Rectangle {
                width: 1.5
                height: tick.len
                color: Theme.line
                anchors.top: tick.onTop ? parent.top : undefined
                anchors.bottom: tick.onTop ? undefined : parent.bottom
                anchors.left: tick.onLeft ? parent.left : undefined
                anchors.right: tick.onLeft ? undefined : parent.right
            }
        }
    }
}
