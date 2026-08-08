import QtQuick
import "Singletons"

// A section eyebrow inside a context menu: a tracked small-caps label with a
// hairline leader, the sidebar's rhythm between control groups. With no label
// it is a plain hairline divider.
Item {
    id: sec

    property string label: ""

    width: parent ? parent.width : 0
    implicitHeight: sec.label.length > 0 ? 26 : 13

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 8

        Text {
            id: cap
            visible: sec.label.length > 0
            anchors.verticalCenter: parent.verticalCenter
            text: sec.label.toUpperCase()
            color: Theme.inkDim
            font.family: Theme.font
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 1.8
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - (cap.visible ? cap.width + parent.spacing : 0)
            height: 1
            color: Theme.line
        }
    }
}
