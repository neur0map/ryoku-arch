pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// analog face. clean dial with twelve ticks (quarters bright), bright ink
// hour + minute hands, thin accent second hand over an accent hub. minute
// hand creeps with the seconds so it never sits between marks; second hand
// ticks. sized square from the scale knob.
Item {
    id: face

    readonly property var t: Clk.parts(Now.date, Config.clock24h)
    readonly property color accent: Clk.pickAccent(Config.clockAccent, Wallust.accent, Theme.brand, Theme.ink)
    readonly property real dia: Math.round(220 * Config.clockScale)
    readonly property real s: Config.clockScale

    implicitWidth: dia
    implicitHeight: dia

    Item {
        id: dial
        anchors.fill: parent

        // faint rim so the dial reads as a face even on a busy wallpaper.
        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: "transparent"
            border.width: Math.max(1, face.s)
            border.color: Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.14)
        }

        // ticks: each wrapper is dial-sized + centred, rotating it sweeps its
        // top tick round the rim.
        Repeater {
            model: 12
            Item {
                required property int index
                readonly property bool major: index % 3 === 0
                anchors.fill: parent
                rotation: index * 30
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.round(8 * face.s)
                    width: parent.major ? Math.round(4 * face.s) : Math.round(2 * face.s)
                    height: parent.major ? Math.round(15 * face.s) : Math.round(8 * face.s)
                    radius: width / 2
                    color: parent.major ? Theme.ink : Theme.inkDim
                }
            }
        }

        // hour.
        Rectangle {
            x: (dial.width - width) / 2
            y: dial.height / 2 - height
            width: Math.round(8 * face.s)
            height: dial.height * 0.28
            radius: width / 2
            color: Theme.ink
            antialiasing: true
            transformOrigin: Item.Bottom
            rotation: face.t.hourAngle
        }

        // minute.
        Rectangle {
            x: (dial.width - width) / 2
            y: dial.height / 2 - height
            width: Math.round(6 * face.s)
            height: dial.height * 0.40
            radius: width / 2
            color: Theme.ink
            antialiasing: true
            transformOrigin: Item.Bottom
            rotation: face.t.minuteAngle
        }

        // second.
        Rectangle {
            x: (dial.width - width) / 2
            y: dial.height / 2 - height
            width: Math.max(2, Math.round(2.5 * face.s))
            height: dial.height * 0.44
            radius: width / 2
            color: face.accent
            antialiasing: true
            transformOrigin: Item.Bottom
            rotation: face.t.secondAngle
        }

        // hub.
        Rectangle {
            anchors.centerIn: parent
            width: Math.round(14 * face.s)
            height: width
            radius: width / 2
            color: face.accent
            border.width: Math.max(1, Math.round(2 * face.s))
            border.color: Theme.ink
        }
    }
}
