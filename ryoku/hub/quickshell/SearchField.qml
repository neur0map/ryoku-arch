import QtQuick
import "Singletons"

// The fuzzy-finder input: a magnifier, the text, a clear glyph, and a plain
// Ctrl K hint while idle. Flat; focus is signalled by an ember edge, not a glow.
Rectangle {
    id: field

    property alias text: input.text
    property string placeholder: "Search\u2026"
    signal escaped()

    function focusInput() { input.forceActiveFocus(); }

    implicitHeight: 40
    radius: 10
    color: input.activeFocus ? Theme.surface : Theme.surfaceLo
    border.width: 1
    border.color: input.activeFocus ? Theme.ember : Theme.line
    Behavior on color { ColorAnimation { duration: Theme.quick } }
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    MouseArea {
        anchors.fill: parent
        onClicked: input.forceActiveFocus()
    }

    Icon {
        id: mag
        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        name: "search"
        size: 16
        tint: input.activeFocus ? Theme.ember : Theme.dim
        Behavior on tint { ColorAnimation { duration: Theme.quick } }
    }

    TextInput {
        id: input
        anchors.left: mag.right
        anchors.leftMargin: 11
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.bright
        font.family: Theme.font
        font.pixelSize: 14
        selectionColor: Theme.ember
        selectedTextColor: Theme.onAccent
        clip: true
        Keys.onEscapePressed: {
            if (text.length > 0)
                text = "";
            else
                field.escaped();
        }

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text.length === 0
            text: field.placeholder
            color: Theme.faint
            font: input.font
        }
    }

    Item {
        id: tail
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 32
        height: parent.height

        Text {
            anchors.centerIn: parent
            visible: input.text.length === 0 && !input.activeFocus
            text: "Ctrl K"
            color: Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
        }

        Icon {
            anchors.centerIn: parent
            visible: input.text.length > 0
            name: "close"
            size: 13
            tint: clear.containsMouse ? Theme.ember : Theme.dim
        }

        MouseArea {
            id: clear
            anchors.fill: parent
            hoverEnabled: true
            enabled: input.text.length > 0
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                input.text = "";
                input.forceActiveFocus();
            }
        }
    }
}
