import QtQuick
import "Singletons"

// A panel section: a small let-spaced title with a hairline, then its content.
Column {
    id: g
    property string title: ""
    default property alias content: body.data
    width: parent ? parent.width : 0
    spacing: 13
    Item {
        width: g.width; height: 13
        Text {
            id: gh
            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
            text: g.title; color: Theme.dim
            font.family: Theme.font; font.pixelSize: 11; font.weight: Font.DemiBold; font.letterSpacing: 2
        }
        Rectangle { anchors.left: gh.right; anchors.leftMargin: 12; anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter; height: 1; color: Theme.hair }
    }
    Column { id: body; width: g.width; spacing: 13 }
}
