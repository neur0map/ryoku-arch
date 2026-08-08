pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// inline date: one quiet caption. weekday in accent, then month + day in soft
// ink, split by a dot. default companion to the time, reads as one line, never
// competes with the clock above.
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
    readonly property real px: Math.round(22 * Config.clockScale)

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    Row {
        id: row
        spacing: Math.round(8 * Config.clockScale)

        Text {
            text: date.dp.weekday
            color: date.accent
            font.family: Theme.font
            font.pixelSize: date.px
            font.weight: Font.DemiBold
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "\u00b7"
            color: date.inkDim
            font.family: Theme.font
            font.pixelSize: date.px
            font.weight: Font.Bold
        }
        Text {
            text: date.dp.month + " " + date.dp.dom
            color: date.inkSoft
            font.family: Theme.font
            font.pixelSize: date.px
            font.weight: Font.Medium
        }
    }
}
