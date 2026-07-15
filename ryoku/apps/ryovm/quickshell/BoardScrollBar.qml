import QtQuick
import QtQuick.Controls
import "Singletons"

// The board's scrollbar: a square 4px thumb on nothing, palette inks. The
// default Qt pill thumb is the last rounded stranger on a radius-0 surface.
ScrollBar {
    id: bar
    policy: ScrollBar.AsNeeded
    implicitWidth: 6
    contentItem: Rectangle {
        implicitWidth: 4
        color: bar.pressed ? Theme.cream : Theme.faint
        antialiasing: false
        opacity: bar.policy === ScrollBar.AlwaysOn || bar.active ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Theme.quick } }
    }
    background: null
}
