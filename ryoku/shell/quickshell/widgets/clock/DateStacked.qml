pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// stacked date: big day number, weekday over month/year. the torn-calendar
// look. most expressive of the date designs; stands on its own under analog
// or rings.
Item {
    id: date

    readonly property var dp: Clk.dateParts(Now.date)
    readonly property color accent: Clk.pickAccent(Config.clockAccent, Wallust.accent, Theme.brand, Theme.ink)
    readonly property real s: Config.clockScale

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: Math.round(14 * date.s)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: date.dp.dom
            color: Theme.ink
            font.family: Theme.mono
            font.pixelSize: Math.round(52 * date.s)
            font.weight: Font.Bold
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: Math.round(3 * date.s)

            Text {
                text: date.dp.weekday
                color: date.accent
                font.family: Theme.font
                font.pixelSize: Math.round(22 * date.s)
                font.weight: Font.DemiBold
            }
            Text {
                text: date.dp.month + " " + date.dp.year
                color: Theme.inkDim
                font.family: Theme.font
                font.pixelSize: Math.round(17 * date.s)
                font.weight: Font.Medium
            }
        }
    }
}
