import QtQuick
import "Singletons"

// A boolean setting: a label and a sliding switch that takes effect at once.
// Used for on/off knobs (the visualiser itself, the idle wave) per the toggle
// convention. Reports toggled(checked).
Item {
    id: row

    property string label: ""
    property bool checked: false

    signal toggled(bool checked)

    implicitWidth: 320
    implicitHeight: 38

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - track.width - 14
        elide: Text.ElideRight
        text: row.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 14
        font.weight: Font.Medium
    }

    Rectangle {
        id: track
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 46
        height: 26
        radius: height / 2
        color: row.checked ? Theme.ember : Theme.surfaceLo
        border.width: 1
        border.color: row.checked ? Theme.ember : (hov.hovered ? Theme.subtle : Theme.line)
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

        Rectangle {
            id: knob
            width: 20
            height: 20
            radius: 10
            y: 3
            x: row.checked ? track.width - width - 3 : 3
            color: row.checked ? Theme.onAccent : Theme.cream
            Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }

        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: row.toggled(!row.checked) }
    }
}
