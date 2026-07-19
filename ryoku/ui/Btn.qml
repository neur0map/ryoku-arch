import QtQuick
import "Singletons"

Rectangle {
    id: btn
    property alias text: lab.text
    property bool primary: false
    property bool armed: true
    property bool compact: false
    signal act()

    implicitWidth: lab.width + (compact ? 20 : 30)
    implicitHeight: compact ? 24 : 32
    radius: Tokens.radius
    opacity: armed ? 1 : 0.3
    color: primary && armed ? Tokens.bone : (bh.hovered && armed ? Tokens.tint10 : "transparent")
    border.width: Tokens.border
    border.color: primary && armed ? Tokens.bone : (bh.hovered && armed ? Tokens.lineStrong : Tokens.line)
    Behavior on color { ColorAnimation { duration: Tokens.snap } }
    Behavior on opacity { NumberAnimation { duration: Tokens.snap } }

    Text {
        id: lab
        anchors.centerIn: parent
        color: btn.primary && btn.armed ? Tokens.inkOnBone : Tokens.ink
        font.family: Tokens.ui
        font.pixelSize: btn.compact ? 10 : 11
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackLabel
    }
    HoverHandler { id: bh; enabled: btn.armed; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: btn.armed; onTapped: btn.act() }
}
