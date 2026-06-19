import QtQuick
import QtQuick.Layouts
import "Singletons"

// One legend line: the action on the left, an optional category tag (plain dim
// mono, no chip), and the key combo as keycaps joined by a faint plus.
RowLayout {
    id: row

    property var keys: []
    property string desc: ""
    property string tag: ""

    spacing: 14

    Text {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignVCenter
        text: row.desc
        color: Theme.subtle
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
        elide: Text.ElideRight
    }

    Text {
        Layout.alignment: Qt.AlignVCenter
        visible: row.tag !== ""
        text: row.tag
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.capitalization: Font.AllUppercase
        font.letterSpacing: 1
    }

    Row {
        Layout.alignment: Qt.AlignVCenter | Qt.AlignRight
        spacing: 5

        Repeater {
            model: row.keys
            delegate: Row {
                spacing: 5

                Text {
                    visible: index > 0
                    height: 25
                    verticalAlignment: Text.AlignVCenter
                    text: "+"
                    color: Theme.faint
                    font.family: Theme.font
                    font.pixelSize: 11
                }

                KeyCap { text: modelData }
            }
        }
    }
}
