import QtQuick
import Ryoku.Ui.Singletons

// Keycap: a flat hairline cap, the KeyboardMap Key vocabulary -- no fill, no
// lip, no sheen; the glyph is Space Grotesk like every legend a human reads.
// `big` grows it for the hero shortcut rows where legibility matters most.
Rectangle {
    id: cap

    property string text: ""
    property bool big: false

    radius: Tokens.radius
    implicitHeight: big ? 32 : 24
    implicitWidth: Math.max(implicitHeight, label.implicitWidth + (big ? 20 : 14))
    color: "transparent"
    border.width: Tokens.border
    border.color: Tokens.line

    Text {
        id: label
        anchors.centerIn: parent
        text: cap.text
        color: Tokens.inkDim
        font.family: Tokens.ui
        font.pixelSize: cap.big ? 12 : 11
        font.weight: Font.Medium
    }
}
