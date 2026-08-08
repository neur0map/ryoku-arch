pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// The middle content of the audio rows (contract 16 sec 2.5, contract 06 sec
// 2.4): an 8px pill progress bar acting as a continuous volume slider. The
// dark track is primary-container, the fill on-primary-container, both 8px
// radius, and there is no visible thumb or keyboard/wheel handling. `value`
// (0..1) is driven by the host from live state; `moved` fires only on a
// pointer drag, so a programmatic value update never echoes back (the
// reference blocks the change signal on SetValue).
Item {
    id: root

    property real value: 0
    property real rightMargin: 20
    // While the pointer holds the bar, show where the finger is, not the value
    // the backend is still catching up to, so the fill never fights the drag.
    property bool dragging: false
    property real dragValue: 0
    readonly property real shown: Math.max(0, Math.min(1, root.dragging ? root.dragValue : root.value))

    signal moved(real value)

    implicitHeight: 48
    implicitWidth: 120

    function commit(px) {
        const w = Math.max(1, track.width);
        root.dragValue = Math.max(0, Math.min(1, px / w));
        root.dragging = true;
        root.moved(root.dragValue);
    }

    Rectangle {
        id: track
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        width: parent.width - root.rightMargin
        height: 8
        radius: 8
        color: Theme.primaryContainer

        Rectangle {
            width: Math.max(8, parent.width * root.shown)
            height: parent.height
            radius: 8
            color: Theme.onPrimaryContainer
        }
    }

    MouseArea {
        anchors.fill: parent
        preventStealing: true
        onPressed: mouse => root.commit(mouse.x)
        onPositionChanged: mouse => { if (pressed) root.commit(mouse.x); }
        onReleased: root.dragging = false
        onCanceled: root.dragging = false
    }
}
