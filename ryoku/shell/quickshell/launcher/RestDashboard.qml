import QtQuick
import Quickshell
import "Singletons"

// Zero-query home: a single card with the time, the date, and a greeting that
// shifts with the hour. Shown when the search field is empty, the way the inir
// rest screen reads before you type.
Item {
    id: root

    property real s: 1
    implicitHeight: 74 * s

    readonly property var now: clock.date
    readonly property string hh: Qt.formatTime(now, "HH")
    readonly property string mm: Qt.formatTime(now, "mm")
    readonly property string meta: {
        var loc = Qt.locale("en_US");
        var wd = loc.toString(now, "ddd").toUpperCase();
        var dt = loc.toString(now, "MMM d").toUpperCase();
        var h = now.getHours();
        var g = h < 5 ? "GOOD NIGHT" : h < 12 ? "GOOD MORNING" : h < 18 ? "GOOD AFTERNOON" : "GOOD EVENING";
        return wd + "  \u00b7  " + dt + "  \u00b7  " + g;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    // left accent rule: the vermilion brand bar the time hangs off, so the rest
    // screen reads as an intentional masthead, not a boxed card.
    Rectangle {
        id: rule
        anchors.left: parent.left
        anchors.leftMargin: Metrics.padRow * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 3 * root.s
        height: 52 * root.s
        radius: 1.5 * root.s
        color: Theme.verm
    }

    Row {
        id: timeRow
        anchors.left: rule.right
        anchors.leftMargin: 14 * root.s
        anchors.top: parent.top
        anchors.topMargin: 10 * root.s
        spacing: 0

        Text {
            text: root.hh
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 38 * root.s
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
        Text {
            text: ":"
            color: Theme.verm
            font.family: Theme.mono
            font.pixelSize: 38 * root.s
            font.weight: Font.Medium
        }
        Text {
            text: root.mm
            color: Theme.bright
            font.family: Theme.mono
            font.pixelSize: 38 * root.s
            font.weight: Font.Medium
            font.features: { "tnum": 1 }
        }
    }

    Text {
        anchors.left: rule.right
        anchors.leftMargin: 15 * root.s
        anchors.top: timeRow.bottom
        anchors.topMargin: 2 * root.s
        text: root.meta
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: Metrics.fontEyebrow * root.s
        font.letterSpacing: 1.5
    }
}
