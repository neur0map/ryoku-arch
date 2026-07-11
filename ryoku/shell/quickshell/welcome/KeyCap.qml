import QtQuick
import "Singletons"

// Keycap: flat warm tile with a darker bottom lip for a hint of mechanical depth,
// glyph in JetBrains Mono. No gradient, no glassy sheen. `big` grows it for the
// hero shortcut rows where legibility matters most.
Rectangle {
    id: cap

    property string text: ""
    property bool big: false

    radius: Theme.radius
    implicitHeight: big ? 36 : 26
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + (big ? 22 : 16))
    color: Theme.keyTop
    border.width: 1
    border.color: Theme.line

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: cap.big ? 4 : 3
        radius: Theme.radius
        color: Theme.keyBot
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: cap.text
        color: Theme.cream
        font.family: Theme.mono
        font.pixelSize: cap.big ? 13 : 11
        font.weight: Font.Medium
    }
}
