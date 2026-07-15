import QtQuick
import "Singletons"

// A hardware slide switch: a recessed slot with a square knob that snaps
// between stops. Ember slot when engaged. Machines don't fade — the knob moves
// fast and hard.
Item {
    id: t
    property bool on: false
    signal toggled(bool v)

    implicitWidth: 42
    implicitHeight: 22
    opacity: enabled ? 1 : 0.4

    // the slot.
    Rectangle {
        anchors.fill: parent
        color: t.on ? Theme.frameBg : Theme.surfaceLo
        border.width: 1
        border.color: t.on ? Theme.ember : Theme.line
        antialiasing: false
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
    }
    // engraved stop marks.
    Rectangle { x: 6; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 8; color: Theme.lineSoft; antialiasing: false }
    Rectangle { x: parent.width - 7; anchors.verticalCenter: parent.verticalCenter; width: 1; height: 8; color: Theme.lineSoft; antialiasing: false }

    // the knob: a keycap that slides between stops.
    Rectangle {
        width: 16
        height: parent.height - 6
        y: 3
        x: t.on ? parent.width - width - 3 : 3
        gradient: Gradient {
            GradientStop { position: 0.0; color: t.on ? Theme.ember : Theme.keyTop }
            GradientStop { position: 1.0; color: t.on ? Theme.emberDeep : Theme.keyBot }
        }
        border.width: 1
        border.color: t.on ? Theme.emberDeep : Theme.lineStrong
        antialiasing: false
        Behavior on x { NumberAnimation { duration: 70; easing.type: Easing.OutQuad } }
    }

    HoverHandler { enabled: t.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: t.enabled; onTapped: t.toggled(!t.on) }
}
