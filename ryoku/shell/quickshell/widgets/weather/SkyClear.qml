pragma ComponentBehavior: Bound
import QtQuick

// clear sky. day: warm sun, soft layered glow, slowly turning rays. night:
// pale moon, faint halo, scatter of twinkling stars. core breathes and rays
// rotate only while animation is on, so a still preview / inhibited desktop
// stays calm.
Item {
    id: sky

    property bool isDay: true
    property bool animate: true
    readonly property real u: Math.min(width, height)

    property real pulse: 1
    SequentialAnimation on pulse {
        running: sky.animate
        loops: Animation.Infinite
        NumberAnimation { from: 1; to: 1.06; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { from: 1.06; to: 1; duration: 2600; easing.type: Easing.InOutSine }
    }

    // -- day: sun -----------------------------------------------------------
    Item {
        anchors.centerIn: parent
        visible: sky.isDay
        width: sky.u
        height: sky.u

        // layered glow, fake a radial halo.
        Rectangle {
            anchors.centerIn: parent
            width: sky.u * 0.86 * sky.pulse
            height: width
            radius: width / 2
            color: Qt.rgba(1, 0.7, 0.32, 0.12)
        }
        Rectangle {
            anchors.centerIn: parent
            width: sky.u * 0.62 * sky.pulse
            height: width
            radius: width / 2
            color: Qt.rgba(1, 0.72, 0.34, 0.2)
        }

        // rays.
        Item {
            anchors.centerIn: parent
            width: sky.u
            height: sky.u
            NumberAnimation on rotation {
                running: sky.animate
                from: 0; to: 360; duration: 90000; loops: Animation.Infinite
            }
            Repeater {
                model: 12
                Item {
                    required property int index
                    anchors.fill: parent
                    rotation: index * 30
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: sky.u * 0.04
                        width: Math.max(2, sky.u * 0.018)
                        height: sky.u * 0.1
                        radius: width / 2
                        color: Qt.rgba(1, 0.81, 0.52, 0.85)
                    }
                }
            }
        }

        // core.
        Rectangle {
            anchors.centerIn: parent
            width: sky.u * 0.44
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#ffe3a8" }
                GradientStop { position: 1.0; color: "#ffb24d" }
            }
        }
    }

    // -- night: moon + stars ------------------------------------------------
    Item {
        anchors.fill: parent
        visible: !sky.isDay

        Rectangle {
            anchors.centerIn: parent
            width: sky.u * 0.6 * sky.pulse
            height: width
            radius: width / 2
            color: Qt.rgba(0.78, 0.82, 1, 0.12)
        }
        Rectangle {
            anchors.centerIn: parent
            width: sky.u * 0.4
            height: width
            radius: width / 2
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#eef2ff" }
                GradientStop { position: 1.0; color: "#c3ccf0" }
            }
        }

        Repeater {
            model: 7
            Rectangle {
                id: star
                required property int index
                readonly property real fx: ((index * 0.6180339) % 1)
                readonly property real fy: ((index * 0.3344) % 1)
                x: sky.width * (0.08 + fx * 0.84)
                y: sky.height * (0.08 + fy * 0.5)
                width: Math.max(2, sky.u * 0.02)
                height: width
                radius: width / 2
                color: "#eaf0ff"
                SequentialAnimation on opacity {
                    running: sky.animate
                    loops: Animation.Infinite
                    NumberAnimation { from: 0.25; to: 0.95; duration: 900 + star.index * 180; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.95; to: 0.25; duration: 900 + star.index * 160; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
