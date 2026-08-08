import QtQuick
import Ryoku.Ui.Singletons

// A settings-group head, Ryoku.Ui Section's label row verbatim: the mono `//`
// lead, the tracked title, a hairline rule, and an end tick registering where
// the rule stops. Step 4 is a miniature settings sheet, so it speaks the
// sheet's vocabulary. Give it an explicit width; the rule fills the remainder.
Row {
    id: head

    property string text: ""

    spacing: Tokens.s2

    Text {
        text: "//"
        color: Tokens.inkFaint
        font.family: Tokens.mono
        font.pixelSize: Tokens.fMicro
        anchors.verticalCenter: parent.verticalCenter
    }
    Text {
        id: title
        text: head.text + "_"
        color: Tokens.ink
        font.family: Tokens.ui
        font.pixelSize: Tokens.fMicro
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackMark
        anchors.verticalCenter: parent.verticalCenter
    }
    Rectangle {
        // the rule swallows whatever width the lead and title leave over.
        width: Math.max(0, head.width - title.x - title.width - 3 * head.spacing - 1)
        height: 1
        color: Tokens.lineSoft
        anchors.verticalCenter: parent.verticalCenter
    }
    Rectangle {
        width: 1
        height: 5
        color: Tokens.line
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -2
    }
}
