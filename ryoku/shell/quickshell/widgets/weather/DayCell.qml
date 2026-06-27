pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// one day in a forecast row: weekday, a small static sky icon for the
// category, hi over lo. shared by every weather design that shows the
// week, so the cell lives in one place. current day = accent.
Item {
    id: cell

    property string day: ""
    property string category: "clouds"
    property int hi: 0
    property int lo: 0
    property bool highlight: false
    property real s: 1
    property color accent: "#7aa2f7"

    implicitWidth: col.implicitWidth
    implicitHeight: col.implicitHeight

    Column {
        id: col
        spacing: Math.round(5 * cell.s)

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cell.day
            color: cell.highlight ? cell.accent : Theme.inkDim
            font.family: Theme.font
            font.pixelSize: Math.round(14 * cell.s)
            font.weight: cell.highlight ? Font.DemiBold : Font.Medium
        }

        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.round(34 * cell.s)
            height: width
            Sky {
                anchors.fill: parent
                category: cell.category
                animate: false
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cell.hi + "\u00b0"
            color: Theme.ink
            font.family: Theme.mono
            font.pixelSize: Math.round(14 * cell.s)
            font.weight: Font.DemiBold
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: cell.lo + "\u00b0"
            color: Theme.inkDim
            font.family: Theme.mono
            font.pixelSize: Math.round(13 * cell.s)
            font.weight: Font.Medium
        }
    }
}
