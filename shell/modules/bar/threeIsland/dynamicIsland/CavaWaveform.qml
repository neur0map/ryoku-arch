import qs.services
import qs.modules.common
import QtQuick

// Renders Cava.bars as N rounded vertical bars. Tweens height changes for
// smoothness even when cava emits at variable rate.
Row {
    id: root
    spacing: 2

    property real maxBarHeight: 18
    property real minBarHeight: 2
    property real barWidth: 3
    property color barColor: "#7ac"

    implicitWidth: (root.barWidth + root.spacing) * Cava.barCount - root.spacing
    implicitHeight: root.maxBarHeight

    Repeater {
        model: Cava.barCount
        delegate: Rectangle {
            required property int index
            anchors.bottom: parent.bottom
            width: root.barWidth
            height: Math.max(root.minBarHeight, (Cava.bars[index] ?? 0) * root.maxBarHeight)
            radius: width / 2
            color: root.barColor

            Behavior on height {
                enabled: Appearance.animationsEnabled
                NumberAnimation { duration: 80; easing.type: Easing.OutQuad }
            }
        }
    }
}
