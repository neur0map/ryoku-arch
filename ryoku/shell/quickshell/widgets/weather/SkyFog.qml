pragma ComponentBehavior: Bound
import QtQuick

// fog: a few soft horizontal haze bands drifting at different speeds on one
// shared phase. lightest-touch sky. clipped so the over-wide bands stay in.
Item {
    id: sky

    property bool isDay: true
    property bool animate: true
    clip: true

    property real drift: 0
    NumberAnimation on drift {
        running: sky.animate
        from: 0; to: Math.PI * 2; duration: 22000; loops: Animation.Infinite
    }

    Repeater {
        model: 4
        Rectangle {
            required property int index
            width: sky.width * 1.3
            height: sky.height * 0.13
            radius: height / 2
            x: -sky.width * 0.15 + Math.sin(sky.drift + index * 1.3) * sky.width * 0.07
            y: sky.height * (0.16 + index * 0.19)
            color: Qt.rgba(0.86, 0.88, 0.95, 0.22 - index * 0.035)
        }
    }
}
