import QtQuick
import "Singletons"

// Faint L-bracket registration ticks at the four corners, framing the panel like
// an editorial specimen sheet. Purely decorative; sits behind the content.
Item {
    id: ticks

    property real s: 1
    property real len: 9 * s
    property color tint: Theme.hair

    // Top-left
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.left: parent.left; anchors.top: parent.top; width: 1; height: ticks.len; color: ticks.tint }
    // Top-right
    Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.right: parent.right; anchors.top: parent.top; width: 1; height: ticks.len; color: ticks.tint }
    // Bottom-left
    Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.left: parent.left; anchors.bottom: parent.bottom; width: 1; height: ticks.len; color: ticks.tint }
    // Bottom-right
    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: ticks.len; height: 1; color: ticks.tint }
    Rectangle { anchors.right: parent.right; anchors.bottom: parent.bottom; width: 1; height: ticks.len; color: ticks.tint }
}
