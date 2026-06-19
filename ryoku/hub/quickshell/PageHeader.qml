import QtQuick
import "Singletons"

// The page title block at the top of the content area.
Item {
    id: header

    property string title: ""
    property string subtitle: ""

    implicitHeight: 80

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Text {
            text: header.title
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 27
            font.weight: Font.DemiBold
            font.letterSpacing: 0.2
        }

        Text {
            text: header.subtitle
            visible: header.subtitle !== ""
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.Medium
        }
    }
}
