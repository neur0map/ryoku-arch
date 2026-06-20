import QtQuick
import "Singletons"

// A nav row: just an icon and a label whose colour tracks state. The selection
// fill/bar is drawn once by the rail's sliding indicator, not per button, so the
// rail reads as one moving accent rather than three boxed chips.
Item {
    id: btn

    property string label: ""
    property string icon: ""
    property bool soon: false
    property int badge: 0
    property bool selected: false
    signal clicked()

    implicitHeight: 44

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 28
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: btn.icon
            size: 18
            tint: btn.selected ? Theme.ember : (hover.hovered ? Theme.cream : Theme.dim)
            Behavior on tint { ColorAnimation { duration: Theme.quick } }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: btn.label
            color: btn.selected ? Theme.bright : (hover.hovered ? Theme.cream : Theme.subtle)
            font.family: Theme.font
            font.pixelSize: 14
            font.weight: btn.selected ? Font.DemiBold : Font.Medium
            Behavior on color { ColorAnimation { duration: Theme.quick } }
        }
    }

    Text {
        visible: btn.soon
        anchors.right: parent.right
        anchors.rightMargin: 26
        anchors.verticalCenter: parent.verticalCenter
        text: "SOON"
        color: Theme.faint
        font.family: Theme.mono
        font.pixelSize: 9
        font.weight: Font.DemiBold
        font.letterSpacing: 1.5
    }

    Rectangle {
        visible: btn.badge > 0
        anchors.right: parent.right
        anchors.rightMargin: 24
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(18, bdg.implicitWidth + 12)
        height: 18
        radius: 9
        color: Theme.ember

        Text {
            id: bdg
            anchors.centerIn: parent
            text: "" + btn.badge
            color: Theme.onAccent
            font.family: Theme.font
            font.pixelSize: 10
            font.weight: Font.Bold
        }
    }

    HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: btn.clicked() }
}
