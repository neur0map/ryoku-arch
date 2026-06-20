import QtQuick
import "Singletons"

// A titled group of controls: a mono uppercase header with a hairline rule, then
// the controls stacked beneath. The hub's section idiom, used to break the shell
// knobs into scannable groups rather than one long list.
Column {
    id: sec

    property string title: ""
    default property alias items: body.data

    spacing: 14

    Item {
        width: sec.width
        height: 16

        Text {
            id: head
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: sec.title
            color: Theme.dim
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }

        Rectangle {
            anchors.left: head.right
            anchors.leftMargin: 14
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Theme.lineSoft
        }
    }

    Column {
        id: body
        width: sec.width
        spacing: 16
    }
}
