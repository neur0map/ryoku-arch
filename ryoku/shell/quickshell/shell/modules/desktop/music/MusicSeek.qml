import QtQuick
import "../Singletons"

// The seek rail: the part already played is a travelling wave in the sleeve's
// colour, the rest a flat hairline, with a handle where the two meet. Drag or
// click anywhere on it to seek.
//
// The wave is painted once into a canvas one wavelength wider than the rail and
// then translated, so motion costs a transform rather than a repaint per frame.
// A canvas repainted every frame here is a known battery and memory sink
// (components/WaveMeter.qml carries that scar).
Item {
    id: rail

    property real s: 1
    property real frac: 0
    property bool live: false
    property color accent: Theme.accent
    property color track: Theme.hair
    property bool seekable: true

    signal seekRequested(real fraction)

    readonly property real amp: 3 * rail.s
    readonly property real wavelength: 15 * rail.s
    readonly property real thickness: 2.2 * rail.s
    readonly property real clamped: Math.max(0, Math.min(1, rail.frac))
    // where the painted wave currently sits; driven by the travel animation.
    property real phase: 0

    implicitHeight: 16 * rail.s

    Rectangle {
        id: rest
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        height: rail.thickness
        radius: height / 2
        color: rail.track
    }

    Item {
        id: played
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: Math.round(rail.width * rail.clamped)
        clip: true

        Behavior on width {
            enabled: rail.live
            NumberAnimation { duration: 250; easing.type: Easing.Linear }
        }

        Canvas {
            id: wave
            y: 0
            height: rail.height
            width: rail.width + rail.wavelength
            x: rail.phase

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const mid = height / 2;
                const k = 6.28318 / rail.wavelength;
                ctx.lineWidth = rail.thickness;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.strokeStyle = rail.accent;
                ctx.beginPath();
                for (let px = 0; px <= width; px += 1.5) {
                    const py = mid + rail.amp * Math.sin(px * k);
                    if (px === 0)
                        ctx.moveTo(px, py);
                    else
                        ctx.lineTo(px, py);
                }
                ctx.stroke();
            }

            onWidthChanged: wave.requestPaint()
            Component.onCompleted: wave.requestPaint()

            Connections {
                target: rail
                function onAccentChanged() { wave.requestPaint(); }
                function onAmpChanged() { wave.requestPaint(); }
            }

        }
    }

    // one wavelength of travel per cycle, so the crest pattern repeats seamlessly
    // and the wave reads as flowing rather than sliding.
    NumberAnimation {
        target: rail
        property: "phase"
        running: rail.live && rail.visible
        loops: Animation.Infinite
        from: -rail.wavelength
        to: 0
        duration: 1100
    }

    Rectangle {
        id: handle
        anchors.verticalCenter: parent.verticalCenter
        x: Math.round(played.width - width / 2)
        width: 3 * rail.s
        height: 12 * rail.s
        radius: width / 2
        color: rail.accent
        visible: rail.seekable
        scale: drag.pressed ? 1.35 : 1
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.topMargin: -6 * rail.s
        anchors.bottomMargin: -6 * rail.s
        enabled: rail.seekable
        cursorShape: Qt.PointingHandCursor
        preventStealing: true

        function emit(x) {
            rail.seekRequested(Math.max(0, Math.min(1, x / rail.width)));
        }
        onPressed: (mouse) => drag.emit(mouse.x)
        onPositionChanged: (mouse) => { if (drag.pressed) drag.emit(mouse.x); }
    }
}
