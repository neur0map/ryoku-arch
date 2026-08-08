import QtQuick
import shell.services

// Section eyebrow: a spaced small-caps label with a hairline leader, the
// sidebar's visual rhythm between control groups.
Item {
    id: root

    property string label: ""

    implicitHeight: 26

    Row {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: 8

        Text {
            id: cap
            anchors.verticalCenter: parent.verticalCenter
            text: root.label.toUpperCase()
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
            font.family: Theme.fontPrimary
            font.pixelSize: Theme.fontSm - 3
            font.weight: Font.DemiBold
            font.letterSpacing: 2
        }
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - cap.width - parent.spacing
            height: 1
            color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.25)
        }
    }
}
