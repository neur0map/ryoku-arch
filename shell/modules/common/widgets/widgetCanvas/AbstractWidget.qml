import QtQuick
import Quickshell
import qs.modules.common

/*
 * Widget to be placed on a WidgetCanvas.
 * Item-based to allow children positioned outside bounds (toolbars) to receive input.
 */
Item {
    id: root

    property alias animateXPos: xBehavior.enabled
    property alias animateYPos: yBehavior.enabled
    property bool draggable: true
    readonly property bool containsPress: _dragArea.pressed
    readonly property bool isDragging: _dragArea.drag.active

    // Drag bounds in parent (canvas) coordinates. Negative dragMaximumX/Y
    // means "unbounded on that side". Subclasses can override to confine the
    // drag to a specific visible region (e.g. background widgets clamp to
    // the visible-screen rectangle even when the canvas is wider under
    // parallax).
    property real dragMinimumX: 0
    property real dragMaximumX: -1
    property real dragMinimumY: 0
    property real dragMaximumY: -1

    signal released()

    function center() {
        root.x = (root.parent.width - root.width) / 2
        root.y = (root.parent.height - root.height) / 2
    }

    MouseArea {
        id: _dragArea
        anchors.fill: parent
        drag.target: root.draggable ? root : undefined
        drag.minimumX: root.dragMinimumX
        drag.maximumX: root.dragMaximumX >= 0 ? root.dragMaximumX : Number.MAX_VALUE
        drag.minimumY: root.dragMinimumY
        drag.maximumY: root.dragMaximumY >= 0 ? root.dragMaximumY : Number.MAX_VALUE
        cursorShape: (root.draggable && pressed) ? Qt.ClosedHandCursor : root.draggable ? Qt.OpenHandCursor : Qt.ArrowCursor
        onReleased: root.released()
    }

    Behavior on x {
        id: xBehavior
        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
    Behavior on y {
        id: yBehavior
        animation: NumberAnimation { duration: Appearance.animation.elementMove.duration; easing.type: Appearance.animation.elementMove.type; easing.bezierCurve: Appearance.animation.elementMove.bezierCurve }
    }
}
