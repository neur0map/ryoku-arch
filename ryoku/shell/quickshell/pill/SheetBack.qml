pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// Consistent back affordance for the stash sub-screens (send, receive, download,
// task): a left chevron and label, top-left, returning to the stash grid. One
// shape everywhere replaces the old per-sheet corner close glyphs.
Rectangle {
    id: b

    property real s: 1
    property string label: "Back"
    signal back()

    width: row.implicitWidth + 16 * s
    height: 24 * s
    radius: 3 * s
    color: area.containsMouse ? Theme.frameBg : "transparent"
    border.width: area.containsMouse ? 1 : 0
    border.color: Theme.frameBorder
    Behavior on color { ColorAnimation { duration: Motion.fast } }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 4 * b.s

        GlyphIcon {
            anchors.verticalCenter: parent.verticalCenter
            width: 13 * b.s
            height: 13 * b.s
            name: "chevron-left"
            color: area.containsMouse ? Theme.cream : Theme.iconDim
            stroke: 1.9
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: b.label
            color: area.containsMouse ? Theme.cream : Theme.subtle
            font.family: Theme.font
            font.pixelSize: 9.5 * b.s
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1 * b.s
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.back()
    }
}
