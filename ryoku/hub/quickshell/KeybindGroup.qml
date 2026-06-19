import QtQuick
import "Singletons"

// A titled group of binds: an ember section header with a trailing hairline rule,
// then the binds as rows split by faint dividers. Shared by the grouped legend
// and the search results (which set `tagged` to show each row's origin).
Column {
    id: group

    property string name: ""
    property var binds: []
    property bool tagged: false

    spacing: 0

    Item {
        width: parent.width
        height: 32

        Text {
            id: secLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: group.name
            color: Theme.ember
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
            font.capitalization: Font.AllUppercase
            font.letterSpacing: 1.5
        }

        Rectangle {
            anchors.left: secLabel.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Theme.lineSoft
        }
    }

    Repeater {
        model: group.binds

        delegate: Column {
            required property var modelData
            required property int index
            width: group.width

            Rectangle {
                visible: index > 0
                width: parent.width
                height: 1
                color: Theme.lineSoft
            }

            KeybindRow {
                width: parent.width
                height: 44
                keys: parent.modelData.keys
                desc: parent.modelData.desc
                tag: group.tagged ? (parent.modelData.cat || "") : ""
            }
        }
    }
}
