pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Colour filter: one rounded swatch per hue group present, led by an ALL chip
// that clears the filter. The pick wears a primary ring; hover lightens; the
// rest dim while a filter is active.
Item {
    id: strip

    required property real s
    required property var groups
    required property int selected
    signal picked(int g)

    readonly property int chip: Math.round(22 * s)
    implicitWidth: rowInner.width
    implicitHeight: chip

    Row {
        id: rowInner
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Math.round(7 * strip.s)

        Rectangle {
            id: all
            readonly property bool on: strip.selected === -1
            width: allTxt.implicitWidth + Math.round(18 * strip.s)
            height: strip.chip
            radius: Math.round(6 * strip.s)
            color: all.on ? Theme.fillActive : Theme.fillIdle
            border.width: 1
            border.color: all.on ? Theme.seal : Theme.sep
            Text {
                id: allTxt
                anchors.centerIn: parent
                text: "All"
                color: all.on ? Theme.seal : Theme.onSurface
                font.family: Theme.mono
                font.pixelSize: Math.round(11 * strip.s)
                font.weight: all.on ? Font.DemiBold : Font.Medium
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: strip.picked(-1) }
        }

        Repeater {
            model: strip.groups
            delegate: Rectangle {
                id: sw
                required property var modelData
                readonly property bool on: strip.selected === sw.modelData
                readonly property bool dimmed: strip.selected !== -1 && !sw.on
                width: strip.chip
                height: strip.chip
                radius: Math.round(6 * strip.s)
                color: hh.hovered ? Qt.lighter(Colors.swatch(sw.modelData), 1.15) : Colors.swatch(sw.modelData)
                opacity: sw.dimmed ? 0.45 : 1
                border.width: sw.on ? Math.max(2, Theme.borderWidth) : 1
                border.color: sw.on ? Theme.seal : Qt.rgba(0, 0, 0, 0.35)
                Behavior on opacity { NumberAnimation { duration: Motion.fast } }
                HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: strip.picked(sw.modelData) }
            }
        }
    }
}
