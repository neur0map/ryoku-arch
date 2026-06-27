pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Shapes

// storm = dark cloud over fast rain, plus a lightning bolt + a screen flash
// fired on a fixed cadence while animation is on. flash double-blinks like
// real lightning, then fades.
Item {
    id: sky

    property bool isDay: true
    property bool animate: true
    readonly property int n: 16
    clip: true

    property real phase: 0
    NumberAnimation on phase {
        running: sky.animate
        from: 0; to: 1; duration: 850; loops: Animation.Infinite
    }

    Cloud {
        width: sky.width * 0.76
        height: sky.height * 0.42
        anchors.horizontalCenter: parent.horizontalCenter
        y: sky.height * 0.04
        tint: "#aab2c8"
        solid: 0.96
    }

    Repeater {
        model: sky.n
        Rectangle {
            required property int index
            readonly property real fx: (index * 0.6180339) % 1
            readonly property real off: (index * 0.382) % 1
            readonly property real len: sky.height * 0.16
            readonly property real span: sky.height + len
            width: Math.max(2, sky.width * 0.007)
            height: len
            radius: width / 2
            antialiasing: true
            rotation: 16
            transformOrigin: Item.Center
            color: Qt.rgba(0.6, 0.72, 0.95, 0.8)
            x: sky.width * (0.05 + fx * 0.9)
            y: ((sky.phase + off) % 1) * span - len + sky.height * 0.3
        }
    }

    // bolt.
    Shape {
        id: bolt
        anchors.centerIn: parent
        anchors.verticalCenterOffset: sky.height * 0.08
        width: sky.width * 0.3
        height: sky.height * 0.5
        opacity: 0
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true
        ShapePath {
            fillColor: "#fff0b8"
            strokeWidth: 0
            scale: Qt.size(bolt.width / 40, bolt.height / 80)
            PathSvg { path: "M22 0 L6 44 L18 44 L12 80 L36 30 L22 30 Z" }
        }
    }

    // flash overlay.
    Rectangle {
        id: flash
        anchors.fill: parent
        color: "#ffffff"
        opacity: 0
    }

    Timer {
        interval: 4200
        running: sky.animate
        repeat: true
        onTriggered: strike.restart()
    }

    SequentialAnimation {
        id: strike
        ParallelAnimation {
            NumberAnimation { target: flash; property: "opacity"; from: 0; to: 0.5; duration: 80 }
            NumberAnimation { target: bolt; property: "opacity"; from: 0; to: 1; duration: 60 }
        }
        NumberAnimation { target: flash; property: "opacity"; to: 0.12; duration: 90 }
        NumberAnimation { target: flash; property: "opacity"; to: 0.45; duration: 70 }
        ParallelAnimation {
            NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 220 }
            NumberAnimation { target: bolt; property: "opacity"; to: 0; duration: 260 }
        }
    }
}
