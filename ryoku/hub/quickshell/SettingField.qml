pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// labelled free-text field: label on the left, an editable box on the right,
// mirroring NumberField / Dropdown so it sits cleanly among the other setting
// rows. commits on Enter or focus loss via committed(value); a blank box shows
// the placeholder.
Item {
    id: root

    property string label: ""
    property string value: ""
    property string placeholder: ""
    property real fieldWidth: 200

    signal committed(string value)

    implicitWidth: 320
    implicitHeight: 38

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - box.width - 14
        elide: Text.ElideRight
        text: root.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Rectangle {
        id: box
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: root.fieldWidth
        height: 30
        radius: Theme.radius
        color: Theme.surfaceLo
        border.width: 1
        border.color: input.activeFocus ? Theme.ember : Theme.line
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

        Text {
            anchors.fill: parent
            anchors.leftMargin: 12
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0 && !input.activeFocus
            text: root.placeholder
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 13
            elide: Text.ElideRight
        }

        TextInput {
            id: input
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            verticalAlignment: TextInput.AlignVCenter
            text: root.value
            color: Theme.bright
            font.family: Theme.font
            font.pixelSize: 13
            font.weight: Font.DemiBold
            clip: true
            selectByMouse: true
            selectionColor: Theme.ember
            selectedTextColor: Theme.onAccent
            onActiveFocusChanged: {
                if (activeFocus)
                    selectAll();
                else
                    text = Qt.binding(() => root.value);
            }
            onEditingFinished: root.committed(input.text.trim())
        }
    }
}
