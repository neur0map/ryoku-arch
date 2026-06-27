import QtQuick
import "Singletons"

// faint L-bracket reg ticks at the four corners, framing the panel like an
// editorial specimen sheet. decorative; sits behind content.
Item {
    id: ticks

    property real s: 1
    property real len: 9 * s
    property color tint: Theme.hair

    // tl
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: ticks.len; color: ticks.tint }
    // tr
    Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: ticks.len; color: ticks.tint }
    // bl
    Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1; height: ticks.len; color: ticks.tint }
    // br
    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1; height: ticks.len; color: ticks.tint }
}
