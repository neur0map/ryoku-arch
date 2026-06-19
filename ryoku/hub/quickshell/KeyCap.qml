import QtQuick
import "Singletons"

// A keycap: a flat warm tile with a darker bottom lip for a hint of mechanical
// depth, and the glyph in JetBrains Mono. No gradient, no glassy sheen.
Rectangle {
    id: cap

    property string text: ""

    radius: 6
    implicitHeight: 25
    implicitWidth: Math.max(25, label.implicitWidth + 16)
    color: Theme.keyTop
    border.width: 1
    border.color: Theme.line

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: 3
        radius: 3
        color: Theme.keyBot
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: cap.text
        color: Theme.cream
        font.family: Theme.mono
        font.pixelSize: 11
        font.weight: Font.Medium
    }
}
