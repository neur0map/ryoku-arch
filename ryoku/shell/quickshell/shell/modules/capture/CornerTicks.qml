import QtQuick
import shell.services

// Faint L-bracket ticks at the four corners. Pure decoration, sits behind content.
Item {
    id: ticks

    property real s: 1
    property real len: 9 * s
    property color tint: Theme.outlineVariant

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
