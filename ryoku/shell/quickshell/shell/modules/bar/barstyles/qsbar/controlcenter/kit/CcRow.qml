import QtQuick
import "../../modules"

// One setting row: a label (+ optional description) on the left, a control slot
// on the right. Put the control as a child; it is reparented into the slot.
Item {
    id: row
    property var root
    property string label: ""
    property string desc: ""
    property int controlWidth: 130
    default property alias control: slot.data

    width: parent ? parent.width : 0
    implicitHeight: Math.max(38, txt.implicitHeight + 12)
    height: implicitHeight

    Column {
        id: txt
        anchors.left: parent.left
        anchors.right: slot.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        UiText {
            text: row.label
            color: row.root.ink
            font.family: row.root.mono
            font.pixelSize: 12
        }
        UiText {
            visible: row.desc !== ""
            width: txt.width
            text: row.desc
            color: row.root.sumi
            font.family: row.root.mono
            font.pixelSize: 10
            wrapMode: Text.WordWrap
            elide: Text.ElideRight
            maximumLineCount: 2
        }
    }

    Item {
        id: slot
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: row.controlWidth
        height: parent.height
    }
}
