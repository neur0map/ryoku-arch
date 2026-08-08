import QtQuick

// Stable compact caret used by every regular V2 panel.
Item {
    id: pointer

    required property var root
    required property real targetX

    anchors.fill: parent
    z: 20

    readonly property real centerX: Math.max(10, Math.min(width - 10,
        targetX - parent.x))
    readonly property bool pointsUp: root.barPosition !== "bottom"

    Rectangle {
        width: 10
        height: 10
        x: Math.round(pointer.centerX - width / 2)
        y: pointer.pointsUp ? -5 : pointer.height - 5
        rotation: 45
        transformOrigin: Item.Center
        antialiasing: true
        color: pointer.root.bg
        border.color: pointer.root.panelOuterBorderColor
        border.width: pointer.root.panelOuterBorderW
    }

    Rectangle {
        x: Math.round(pointer.centerX - 7)
        y: pointer.pointsUp ? 0 : pointer.height - 8
        width: 14
        height: 8
        color: pointer.root.bg
    }
}
