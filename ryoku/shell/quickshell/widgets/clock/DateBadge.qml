pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"
import "lib/clock.js" as Clk

// badge date = accent-tinted chip, big day number with weekday/month stacked
// beside it. compact mark, pairs with the minimal and digital faces.
Item {
    id: date

    readonly property var dp: Clk.dateParts(Now.date)
    readonly property color accent: Clk.pickAccent(Config.clockAccent, Wallust.accent, Theme.brand, Theme.ink)
    readonly property real s: Config.clockScale

    implicitWidth: chip.implicitWidth
    implicitHeight: chip.implicitHeight

    Rectangle {
        id: chip
        implicitWidth: inner.implicitWidth + Math.round(28 * date.s)
        implicitHeight: inner.implicitHeight + Math.round(16 * date.s)
        radius: Math.round(14 * date.s)
        color: Qt.rgba(date.accent.r, date.accent.g, date.accent.b, 0.16)
        border.width: Math.max(1, Math.round(date.s))
        border.color: Qt.rgba(date.accent.r, date.accent.g, date.accent.b, 0.42)

        Row {
            id: inner
            anchors.centerIn: parent
            spacing: Math.round(12 * date.s)

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: date.dp.dom
                color: Theme.ink
                font.family: Theme.mono
                font.pixelSize: Math.round(40 * date.s)
                font.weight: Font.Bold
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Math.round(2 * date.s)

                Text {
                    text: date.dp.weekdayShort.toUpperCase()
                    color: date.accent
                    font.family: Theme.font
                    font.pixelSize: Math.round(15 * date.s)
                    font.weight: Font.DemiBold
                    font.letterSpacing: Math.round(2 * date.s)
                }
                Text {
                    text: date.dp.month
                    color: Theme.inkSoft
                    font.family: Theme.font
                    font.pixelSize: Math.round(15 * date.s)
                    font.weight: Font.Medium
                }
            }
        }
    }
}
