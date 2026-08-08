pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// stacked date: big day number, weekday over month/year. the torn-calendar
// look. most expressive of the date designs; stands on its own under analog
// or rings.
Item {
    id: date

    // the widget floats on the wallpaper, so its ink is picked against the patch
    // of picture under it. WidgetSlot measures it and pushes it in.
    property real underL: Scheme.wallLstar
    readonly property color ink:     Theme.inkOn(date.underL)
    readonly property color inkDim:  Theme.inkDimOn(date.underL)
    readonly property color inkSoft: Theme.inkSoftOn(date.underL)

    readonly property var dp: Clk.dateParts(Now.date)
    readonly property color accent: Clk.pickAccent(Config.clockAccent, Theme.accentOn(date.underL), Theme.brand, date.ink)
    readonly property real s: Config.clockScale

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: Math.round(14 * date.s)

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: date.dp.dom
            color: date.ink
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
                color: date.inkDim
                font.family: Theme.font
                font.pixelSize: Math.round(17 * date.s)
                font.weight: Font.Medium
            }
        }
    }
}
