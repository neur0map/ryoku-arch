pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../components"

// Visual edit-handle indicators for the camera bubble. The drag logic lives in
// CameraOverlay's single DragHandler, which moves / resizes / rounds by press
// zone -- so these are pure visuals (no competing handlers) plus one flip tap.
// A roundness dot (top-left, at `rad` along the diagonal), a resize grip
// (bottom-right, kept inside the input mask), a flip toggle (top-right), and
// readouts driven by the current drag `mode`. Revealed on hover, hidden while
// recording so they are never in the shot.
Item {
    id: handles

    // "" | "move" | "resize" | "round" -- set by the overlay, drives the readouts.
    property string mode: ""

    readonly property real maxRad: Math.min(width, height) / 2
    readonly property real rad: Camera.roundness * handles.maxRad

    // roundness dot (top-left, sits `rad` in along the diagonal)
    Rectangle {
        width: 14
        height: 14
        radius: width / 2
        x: handles.rad - width / 2
        y: handles.rad - height / 2
        color: Theme.onSurface
        border.width: 2
        border.color: Theme.primary
        HoverHandler { cursorShape: Qt.SizeFDiagCursor }
    }
    Rectangle { // "Radius N" readout
        visible: handles.mode === "round"
        x: handles.rad + 12
        y: handles.rad - height / 2
        width: rL.implicitWidth + 12
        height: rL.implicitHeight + 8
        radius: 5
        color: Qt.rgba(0, 0, 0, 0.72)
        Text {
            id: rL
            anchors.centerIn: parent
            text: "Radius " + Math.round(handles.rad)
            color: Theme.onSurface
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    // resize grip (bottom-right, inset so it stays inside the bubble input mask)
    Rectangle {
        width: 16
        height: 16
        radius: 3
        x: handles.width - width - 5
        y: handles.height - height - 5
        color: Theme.onSurface
        border.width: 2
        border.color: Theme.primary
        HoverHandler { cursorShape: Qt.SizeFDiagCursor }
    }
    Rectangle { // "W x H" readout
        visible: handles.mode === "resize"
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 28
        anchors.bottomMargin: 6
        width: sL.implicitWidth + 12
        height: sL.implicitHeight + 8
        radius: 5
        color: Qt.rgba(0, 0, 0, 0.72)
        Text {
            id: sL
            anchors.centerIn: parent
            text: Math.round(Camera.bw) + " x " + Math.round(Camera.bh)
            color: Theme.onSurface
            font.family: Theme.mono
            font.pixelSize: 11
            font.weight: Font.DemiBold
        }
    }

    // flip toggle (top-right) -- a tap target; taps do not compete with the drag.
    Rectangle {
        id: flipBtn
        width: 26
        height: 26
        radius: width / 2
        x: handles.width - width - 6
        y: 6
        color: Qt.rgba(0, 0, 0, flipHov.hovered ? 0.72 : 0.5)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.12)
        GlyphIcon {
            anchors.centerIn: parent
            width: 15
            height: 15
            name: "flip"
            color: Camera.flipped ? Theme.primary : Theme.onSurface
            stroke: 1.7
        }
        HoverHandler { id: flipHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Camera.flipped = !Camera.flipped }
    }
}
