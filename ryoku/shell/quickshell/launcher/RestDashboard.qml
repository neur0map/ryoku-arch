import QtQuick
import Quickshell
import "Singletons"

// Zero-query home: one filled card. The clock sits on the left (mono numerals
// with a vermilion colon), a weather glance on the right fills what was dead
// space. Mixed-case date + greeting; corner radius steps one inside the window so
// nested corners read concentric. No accent bar.
Item {
    id: root

    property real s: 1
    implicitHeight: 86 * s

    readonly property var now: clock.date
    readonly property string hh: Qt.formatTime(now, "HH")
    readonly property string mm: Qt.formatTime(now, "mm")
    readonly property string date: Qt.locale("en_US").toString(now, "dddd, MMM d")
    readonly property string greeting: {
        var h = now.getHours();
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    Squircle {
        anchors.fill: parent
        radius: Metrics.radiusCard
        power: 4
        color: Theme.frameBg
        borderColor: Theme.hair
        borderWidth: 1

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 16 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * root.s

            Row {
                spacing: 0
                Text {
                    text: root.hh
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 34 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
                Text {
                    text: ":"
                    color: Theme.verm
                    font.family: Theme.mono
                    font.pixelSize: 34 * root.s
                    font.weight: Font.Medium
                }
                Text {
                    text: root.mm
                    color: Theme.bright
                    font.family: Theme.mono
                    font.pixelSize: 34 * root.s
                    font.weight: Font.Medium
                    font.features: { "tnum": 1 }
                }
            }
            Text {
                text: root.greeting
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Metrics.fontSubtitle * root.s
            }
        }

        // weather glance, or just the date until weather resolves, so the right
        // column is never empty.
        Column {
            anchors.right: parent.right
            anchors.rightMargin: 16 * root.s
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3 * root.s

            Text {
                anchors.right: parent.right
                text: Weather.available ? Weather.temp : root.date
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: Weather.available ? 22 * root.s : 13 * root.s
                font.weight: Weather.available ? Font.Medium : Font.Normal
            }
            Text {
                anchors.right: parent.right
                visible: Weather.available
                text: Weather.condition + (Weather.city.length ? "  \u00b7  " + Weather.city : "")
                color: Theme.subtle
                font.family: Theme.font
                font.pixelSize: Metrics.fontSubtitle * root.s
            }
            Text {
                anchors.right: parent.right
                visible: Weather.available
                text: root.date
                color: Theme.faint
                font.family: Theme.font
                font.pixelSize: Metrics.fontEyebrow * root.s
            }
        }
    }
}
