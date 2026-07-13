pragma ComponentBehavior: Bound

import QtQuick
import "Singletons"

// Figma-style on-canvas edit handles for the camera bubble, drawn over the feed:
// a roundness dot (top-left, sits `rad` in along the diagonal), a free-form
// resize grip (bottom-right), and a flip toggle (top-right), each with a live
// readout. Fills the bubble and writes Camera; the overlay reveals it on hover
// and hides it while recording, so it is never in the shot. Each handle is a
// dedicated grip whose DragHandler (dragThreshold 0) wins the grab over the
// bubble's move-drag (threshold 8).
Item {
    id: handles

    // largest edge the resize grip allows (screen-relative; set by the overlay).
    property real maxEdge: 800

    readonly property real maxRad: Math.min(width, height) / 2
    readonly property real rad: Camera.roundness * handles.maxRad

    // scene point -> handles-local (origin = bubble top-left).
    function local(sx, sy) {
        return handles.mapFromItem(null, sx, sy);
    }

    // ── roundness dot: rests `rad` in along the top-left diagonal ─────────────
    Rectangle {
        id: roundDot
        width: 14
        height: 14
        radius: width / 2
        x: handles.rad - width / 2
        y: handles.rad - height / 2
        color: Theme.cream
        border.width: 2
        border.color: Theme.brand

        HoverHandler { cursorShape: Qt.SizeFDiagCursor }
        DragHandler {
            id: roundDrag
            target: null
            dragThreshold: 0
            onCentroidChanged: {
                if (!roundDrag.active)
                    return;
                const p = handles.local(roundDrag.centroid.scenePosition.x, roundDrag.centroid.scenePosition.y);
                const d = Math.max(0, Math.min(handles.maxRad, (p.x + p.y) / 2));
                Camera.roundness = handles.maxRad > 0 ? d / handles.maxRad : 0;
            }
        }

        Rectangle { // "Radius N" readout, only while dragging
            visible: roundDrag.active
            anchors.left: parent.right
            anchors.leftMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: rLabel.implicitWidth + 12
            height: rLabel.implicitHeight + 8
            radius: 5
            color: Qt.rgba(0, 0, 0, 0.72)
            Text {
                id: rLabel
                anchors.centerIn: parent
                text: "Radius " + Math.round(handles.rad)
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    // ── resize grip: free-form width/height from the bottom-right corner ──────
    Rectangle {
        id: resizeGrip
        width: 16
        height: 16
        radius: 3
        x: handles.width - width / 2
        y: handles.height - height / 2
        color: Theme.cream
        border.width: 2
        border.color: Theme.brand

        HoverHandler { cursorShape: Qt.SizeFDiagCursor }
        DragHandler {
            id: sizeDrag
            target: null
            dragThreshold: 0
            onCentroidChanged: {
                if (!sizeDrag.active)
                    return;
                const p = handles.local(sizeDrag.centroid.scenePosition.x, sizeDrag.centroid.scenePosition.y);
                Camera.bw = Math.max(Camera.minEdge, Math.min(handles.maxEdge, p.x));
                Camera.bh = Math.max(Camera.minEdge, Math.min(handles.maxEdge, p.y));
            }
        }

        Rectangle { // "W x H" readout, only while dragging
            visible: sizeDrag.active
            anchors.right: parent.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: sLabel.implicitWidth + 12
            height: sLabel.implicitHeight + 8
            radius: 5
            color: Qt.rgba(0, 0, 0, 0.72)
            Text {
                id: sLabel
                anchors.centerIn: parent
                text: Math.round(Camera.bw) + " x " + Math.round(Camera.bh)
                color: Theme.cream
                font.family: Theme.mono
                font.pixelSize: 11
                font.weight: Font.DemiBold
            }
        }
    }

    // ── flip toggle (top-right) ───────────────────────────────────────────────
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
            color: Camera.flipped ? Theme.brand : Theme.cream
            stroke: 1.7
        }
        HoverHandler { id: flipHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: Camera.flipped = !Camera.flipped }
    }
}
