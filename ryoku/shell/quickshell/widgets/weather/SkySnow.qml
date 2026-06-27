pragma ComponentBehavior: Bound
import QtQuick

// snow: pale cloud over flakes that fall slowly and sway side to side on one
// shared phase, spread by the golden ratio. clipped to the sky.
Item {
    id: sky

    property bool isDay: true
    property bool animate: true
    readonly property int n: 14
    clip: true

    property real phase: 0
    NumberAnimation on phase {
        running: sky.animate
        from: 0; to: 1; duration: 4600; loops: Animation.Infinite
    }

    Cloud {
        width: sky.width * 0.72
        height: sky.height * 0.4
        anchors.horizontalCenter: parent.horizontalCenter
        y: sky.height * 0.06
        tint: "#dfe6f5"
        solid: 0.95
    }

    Repeater {
        model: sky.n
        Rectangle {
            required property int index
            readonly property real fx: (index * 0.6180339) % 1
            readonly property real off: (index * 0.382) % 1
            readonly property real d: Math.max(3, sky.width * 0.022)
            readonly property real span: sky.height + d
            width: d
            height: d
            radius: d / 2
            color: "#f2f6ff"
            opacity: 0.92
            x: sky.width * (0.05 + fx * 0.88) + Math.sin((sky.phase + off) * Math.PI * 2) * sky.width * 0.03
            y: ((sky.phase + off) % 1) * span - d + sky.height * 0.22
        }
    }
}
