import QtQuick
import "Singletons"

// One operating system in the catalogue: the project's own brand icon over a
// carbon tile, the name beneath. Hover lifts the border; the picked one wears an
// ember frame. Icons load async from quickemu-icons with a glyph fallback.
Rectangle {
    id: cell

    property var entry
    property bool active: false
    signal picked()

    radius: 12
    color: Theme.surfaceLo
    border.width: cell.active ? 1.6 : 1
    border.color: cell.active ? Theme.ember : (ma.containsMouse ? Qt.alpha(Theme.cream, 0.32) : Theme.line)
    clip: true
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    Column {
        anchors.centerIn: parent
        spacing: 9
        width: parent.width - 20

        OsIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52
            height: 52
            size: 52
            slug: cell.entry ? cell.entry.os : ""
            remote: cell.entry ? (cell.entry.svg || cell.entry.png || "") : ""
            label: cell.entry ? cell.entry.name : ""
            glyphTint: Theme.subtle
        }

        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            text: cell.entry ? cell.entry.name : ""
            color: cell.active ? Theme.ember : Theme.cream
            font.family: Theme.font
            font.pixelSize: 12
            font.weight: cell.active ? Font.DemiBold : Font.Medium
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
    }

    // ember corner tick on the active tile.
    Rectangle {
        visible: cell.active
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 7
        width: 16
        height: 16
        radius: 8
        color: Theme.ember
        Icon { anchors.centerIn: parent; name: "check"; size: 11; weight: 2.2; tint: Theme.onAccent }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cell.picked()
    }
}
