import QtQuick
import Ryoku.Ui.Singletons

// Editorial kicker above a Fraunces heading: a hairline tick, the 力 mark, then
// a tracked Space Grotesk label. The mark may carry the brand sun (frame, 力,
// art are the accent's only homes); the rest is ink.
Row {
    id: eye

    property string text: ""
    property bool mark: true

    spacing: 10

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 1
        color: Tokens.lineStrong
    }

    BrandMark {
        visible: eye.mark
        anchors.verticalCenter: parent.verticalCenter
        size: 12
        color: Tokens.sun
        weight: Font.Bold
        opacity: 0.9
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: eye.text
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: 10
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackMark
        font.capitalization: Font.AllUppercase
    }
}
