import QtQuick
import Ryoku.Ui.Singletons
import "Singletons"

// One operating system in the catalogue: the project's own brand logo (colour:
// it is the catalogue's data), the name beneath. Hover lifts the border; the
// picked tile wears the gallery grammar (ink border, tint10 fill, corner dot).
// The ember tick square dies.
Rectangle {
    id: cell

    property var entry
    property bool active: false
    signal picked()

    radius: Tokens.radius
    color: cell.active ? Tokens.tint10 : (ma.containsMouse ? Tokens.tint5 : "transparent")
    border.width: Tokens.border
    border.color: cell.active ? Tokens.ink : (ma.containsMouse ? Tokens.lineStrong : Tokens.line)
    clip: true
    antialiasing: false
    Behavior on color { ColorAnimation { duration: Tokens.snap } }
    Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

    Column {
        anchors.centerIn: parent
        spacing: 9
        width: parent.width - 20

        OsIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 52; height: 52; size: 52
            slug: cell.entry ? cell.entry.os : ""
            label: cell.entry ? cell.entry.name : ""
        }
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            maximumLineCount: 1
            text: cell.entry ? cell.entry.name : ""
            color: cell.active ? Tokens.ink : Tokens.inkDim
            font.family: Tokens.ui
            font.pixelSize: 12
            font.weight: cell.active ? Font.DemiBold : Font.Medium
        }
    }

    // the gallery grammar's corner dot on the picked tile.
    Rectangle {
        visible: cell.active
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 7
        width: 5; height: 5
        radius: 2.5
        color: Tokens.ink
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: cell.picked()
    }
}
