import QtQuick
import "Singletons"

// boolean. two named modes are a Seg, not a switch.
Rectangle {
    id: sw
    property bool on: false
    signal toggled(bool v)

    activeFocusOnTab: true
    function activate() { toggled(!on) }
    Keys.onPressed: event => {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) {
            activate();
            event.accepted = true;
        }
    }

    implicitWidth: 54
    implicitHeight: 24
    radius: Tokens.radius
    color: "transparent"
    border.width: Tokens.border
    border.color: activeFocus ? Tokens.bone : (hh.hovered ? Tokens.lineStrong : Tokens.line)
    antialiasing: false
    Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

    Rectangle {
        width: 25
        height: 17
        y: 3
        x: sw.on ? parent.width - width - 3 : 3
        radius: Tokens.radius
        antialiasing: false
        color: sw.on ? Tokens.ink : "transparent"
        border.width: sw.on ? 0 : Tokens.border
        border.color: Tokens.line
        Behavior on x { NumberAnimation { duration: Tokens.snap; easing.type: Tokens.easeSnap } }
    }
    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: sw.toggled(!sw.on) }
}
