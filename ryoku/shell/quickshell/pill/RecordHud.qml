pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Blobs
import "Singletons"

// Draggable recording control that lives in the frame's blob field. At rest it
// is fused to a frame edge; grabbing the 6-dot handle pulls it into a floating
// island, and as it nears an edge the blob reach stretches to weld through the
// border, so the two surfaces reach for each other like magnets. Let go and it
// falls to the nearest edge. On a side edge it turns vertical. It melts out of
// the frame when recording begins and back into it when recording ends, so it
// never leaves a mark. Everything eases slowly; nothing snaps.
Item {
    id: hud

    required property var group
    property real s: 1
    property real radius: 17 * s
    property real smoothing: 30

    readonly property int moveDur: 560
    readonly property int meltDur: 620

    anchors.fill: parent

    readonly property real lip: Math.max(0, Config.frameBorder - 50)

    // melt: 0 fully in the border, 1 fully out. drives appear / disappear and
    // gates group membership so a hidden HUD leaves no weld behind.
    property real prog: 0
    states: State { name: "out"; when: Recorder.active; PropertyChanges { hud.prog: 1 } }
    transitions: Transition { NumberAnimation { property: "prog"; duration: hud.meltDur; easing.type: Easing.InOutCubic } }
    readonly property bool live: hud.prog > 0.002
    visible: hud.live

    property string dockEdge: "bottom"
    property real alongPx: 0
    property bool placed: false
    onWidthChanged: hud.reposition()
    onHeightChanged: hud.reposition()
    function reposition() {
        if (hud.placed || hud.width <= 0)
            return;
        hud.alongPx = (hud.width - hud.bodyW) / 2;
        hud.placed = true;
    }

    property bool dragging: false
    property real freeX: 0
    property real freeY: 0

    // turn vertical whenever a side edge is the nearest one and within range, so
    // it reorients while still held, not only after release.
    readonly property real orientThreshold: 220 * hud.s
    readonly property int mergeDur: 850
    readonly property bool vertical: (hud.nearEdge === "left" || hud.nearEdge === "right") && hud.nearGap < hud.orientThreshold
    // the layout flips only at the bottom of a fade dip so the reflow is never
    // seen; the blob morphs across the change, both ways.
    property bool layoutVertical: false
    onVerticalChanged: reorient.restart()
    property real reorientFade: 1
    SequentialAnimation {
        id: reorient
        NumberAnimation { target: hud; property: "reorientFade"; to: 0; duration: 240; easing.type: Easing.InOutCubic }
        ScriptAction { script: hud.layoutVertical = hud.vertical }
        NumberAnimation { target: hud; property: "reorientFade"; to: 1; duration: 380; easing.type: Easing.InOutCubic }
    }
    Component.onCompleted: hud.layoutVertical = hud.vertical

    // body tracks the control grid, which reflows between a row and a column;
    // the size morphs so the blob reshapes as it turns.
    property real bodyW: grid.implicitWidth + 20 * hud.s
    property real bodyH: grid.implicitHeight + 14 * hud.s
    Behavior on bodyW { NumberAnimation { duration: hud.moveDur; easing.type: Easing.InOutCubic } }
    Behavior on bodyH { NumberAnimation { duration: hud.moveDur; easing.type: Easing.InOutCubic } }

    readonly property real dockX: hud.dockEdge === "left" ? hud.lip
        : hud.dockEdge === "right" ? (hud.width - hud.lip - hud.bodyW)
        : Math.max(hud.lip, Math.min(hud.width - hud.lip - hud.bodyW, hud.alongPx))
    readonly property real dockY: hud.dockEdge === "top" ? hud.lip
        : hud.dockEdge === "bottom" ? (hud.height - hud.lip - hud.bodyH)
        : Math.max(hud.lip, Math.min(hud.height - hud.lip - hud.bodyH, hud.alongPx))

    property real px: hud.dragging ? hud.freeX : hud.dockX
    property real py: hud.dragging ? hud.freeY : hud.dockY
    Behavior on px { enabled: !hud.dragging; NumberAnimation { duration: hud.mergeDur; easing.type: Easing.InOutCubic } }
    Behavior on py { enabled: !hud.dragging; NumberAnimation { duration: hud.mergeDur; easing.type: Easing.InOutCubic } }

    readonly property real hudX: hud.px
    readonly property real hudY: hud.py
    readonly property real hudW: hud.bodyW
    readonly property real hudH: hud.bodyH

    // nearest edge + how far the pill face sits from it; drives the magnet reach.
    readonly property real gapT: hud.py - hud.lip
    readonly property real gapB: (hud.height - hud.lip) - (hud.py + hud.bodyH)
    readonly property real gapL: hud.px - hud.lip
    readonly property real gapR: (hud.width - hud.lip) - (hud.px + hud.bodyW)
    readonly property real nearGap: Math.max(0, Math.min(hud.gapT, hud.gapB, hud.gapL, hud.gapR))
    readonly property string nearEdge: {
        var m = Math.min(hud.gapT, hud.gapB, hud.gapL, hud.gapR);
        return m === hud.gapT ? "top" : m === hud.gapB ? "bottom" : m === hud.gapL ? "left" : "right";
    }
    readonly property real threshold: 90 * hud.s
    readonly property real approach: Math.max(0, Math.min(1, 1 - hud.nearGap / hud.threshold))
    readonly property real pull: hud.approach * hud.approach
    // both surfaces reach for each other: the island covers half the gap plus its
    // weld into the border, the frame bump covers the other half, and smooth-min
    // bridges the middle, so they meet like two drops rather than one reaching.
    readonly property real islandReach: (hud.nearGap / 2 + hud.lip + hud.smoothing) * hud.pull
    readonly property real bumpReach: (hud.nearGap / 2 + hud.smoothing) * hud.pull
    readonly property real extT: hud.nearEdge === "top" ? hud.islandReach : 0
    readonly property real extB: hud.nearEdge === "bottom" ? hud.islandReach : 0
    readonly property real extL: hud.nearEdge === "left" ? hud.islandReach : 0
    readonly property real extR: hud.nearEdge === "right" ? hud.islandReach : 0

    // face = the blob's visible rect. melt shrinks it into the docked edge as
    // prog drops, anchored at that edge, so it sinks into the border and leaves.
    readonly property bool vDock: hud.dockEdge === "left" || hud.dockEdge === "right"
    readonly property real faceW: hud.vDock ? hud.bodyW * hud.prog : hud.bodyW
    readonly property real faceH: hud.vDock ? hud.bodyH : hud.bodyH * hud.prog
    readonly property real faceX: hud.dockEdge === "right" ? (hud.px + hud.bodyW - hud.faceW) : hud.px
    readonly property real faceY: hud.dockEdge === "bottom" ? (hud.py + hud.bodyH - hud.faceH) : hud.py

    // frame bump: a blob welded to the near edge that swells toward the island,
    // aligned with it, so the frame reaches back as they close.
    readonly property bool bumpVert: hud.nearEdge === "top" || hud.nearEdge === "bottom"
    readonly property real bumpLen: hud.bumpReach + hud.lip + hud.smoothing
    readonly property real bumpX: hud.nearEdge === "right" ? (hud.width - hud.lip - hud.bumpReach)
        : hud.nearEdge === "left" ? -hud.smoothing
        : hud.px
    readonly property real bumpY: hud.nearEdge === "bottom" ? (hud.height - hud.lip - hud.bumpReach)
        : hud.nearEdge === "top" ? -hud.smoothing
        : hud.py

    BlobRect {
        id: bodyBlob
        group: hud.live ? hud.group : null
        stiffness: 110
        damping: 15
        deformScale: 0.00003
        x: hud.faceX - hud.extL
        y: hud.faceY - hud.extT
        implicitWidth: hud.faceW + hud.extL + hud.extR
        implicitHeight: hud.faceH + hud.extT + hud.extB
        topLeftRadius: (hud.extT > 0 || hud.extL > 0) ? 0 : hud.radius
        topRightRadius: (hud.extT > 0 || hud.extR > 0) ? 0 : hud.radius
        bottomLeftRadius: (hud.extB > 0 || hud.extL > 0) ? 0 : hud.radius
        bottomRightRadius: (hud.extB > 0 || hud.extR > 0) ? 0 : hud.radius
    }

    BlobRect {
        id: frameBump
        group: (hud.live && hud.nearGap > 2 && hud.bumpReach > 0.5) ? hud.group : null
        stiffness: 110
        damping: 15
        deformScale: 0.00003
        x: hud.bumpX
        y: hud.bumpY
        implicitWidth: hud.bumpVert ? hud.bodyW : hud.bumpLen
        implicitHeight: hud.bumpVert ? hud.bumpLen : hud.bodyH
        topLeftRadius: (hud.nearEdge === "top" || hud.nearEdge === "left") ? 0 : hud.radius
        topRightRadius: (hud.nearEdge === "top" || hud.nearEdge === "right") ? 0 : hud.radius
        bottomLeftRadius: (hud.nearEdge === "bottom" || hud.nearEdge === "left") ? 0 : hud.radius
        bottomRightRadius: (hud.nearEdge === "bottom" || hud.nearEdge === "right") ? 0 : hud.radius
    }

    Item {
        id: content
        x: hud.px
        y: hud.py
        width: hud.bodyW
        height: hud.bodyH
        opacity: hud.prog * hud.reorientFade
        transform: Matrix4x4 { matrix: bodyBlob.deformMatrix }

        // one control set that reflows: a row when wide, a column when tall.
        Grid {
            id: grid
            anchors.centerIn: parent
            columns: hud.layoutVertical ? 1 : 99
            rowSpacing: 7 * hud.s
            columnSpacing: 8 * hud.s
            horizontalItemAlignment: Grid.AlignHCenter
            verticalItemAlignment: Grid.AlignVCenter

            // 6-dot grip: the drag handle.
            Item {
                width: 16 * hud.s
                height: 20 * hud.s
                Grid {
                    anchors.centerIn: parent
                    columns: 2
                    rowSpacing: 3 * hud.s
                    columnSpacing: 3 * hud.s
                    Repeater {
                        model: 6
                        Rectangle {
                            width: 3 * hud.s
                            height: 3 * hud.s
                            radius: width / 2
                            color: gripHov.hovered ? Theme.cream : Theme.subtle
                        }
                    }
                }
                HoverHandler { id: gripHov; cursorShape: Qt.SizeAllCursor }
                DragHandler {
                    id: dragH
                    target: null
                    property real sx: 0
                    property real sy: 0
                    property real ax: 0
                    property real ay: 0
                    onActiveChanged: {
                        if (dragH.active) {
                            hud.dragging = true;
                            dragH.sx = hud.px;
                            dragH.sy = hud.py;
                            dragH.ax = dragH.centroid.scenePosition.x;
                            dragH.ay = dragH.centroid.scenePosition.y;
                        } else {
                            hud.alongPx = (hud.nearEdge === "top" || hud.nearEdge === "bottom") ? hud.px : hud.py;
                            hud.dockEdge = hud.nearEdge;
                            hud.dragging = false;
                        }
                    }
                    onCentroidChanged: {
                        if (!dragH.active)
                            return;
                        hud.freeX = Math.max(hud.lip, Math.min(hud.width - hud.lip - hud.bodyW, dragH.sx + (dragH.centroid.scenePosition.x - dragH.ax)));
                        hud.freeY = Math.max(hud.lip, Math.min(hud.height - hud.lip - hud.bodyH, dragH.sy + (dragH.centroid.scenePosition.y - dragH.ay)));
                    }
                }
            }

            Rectangle {
                width: 9 * hud.s
                height: 9 * hud.s
                radius: width / 2
                color: Recorder.paused ? Theme.faint : Theme.vermLit
                opacity: Recorder.paused ? 1 : Recorder.pulse
            }

            Text {
                text: Recorder.elapsedText
                color: Theme.cream
                font.family: Theme.font
                font.pixelSize: 13 * hud.s
                font.features: { "tnum": 1 }
            }

            RecordButton {
                visible: Recorder.canPause
                s: hud.s
                glyph: Recorder.paused ? "play" : "pause"
                tint: Theme.cream
                onTapped: Recorder.togglePause()
            }
            RecordButton {
                s: hud.s
                glyph: "stop"
                tint: Theme.vermLit
                onTapped: Recorder.stop()
            }
            RecordButton {
                s: hud.s
                glyph: hud.sinkMuted ? "speaker-off" : "speaker"
                tint: hud.sinkMuted ? Theme.faint : Theme.cream
                onTapped: hud.toggleSink()
            }
            RecordButton {
                s: hud.s
                glyph: hud.micMuted ? "mic-off" : "mic"
                tint: hud.micMuted ? Theme.faint : Theme.cream
                onTapped: hud.toggleMic()
            }
        }
    }

    // audio mute through the shared Pipewire graph.
    readonly property bool sinkMuted: !!(Audio.sink && Audio.sink.audio && Audio.sink.audio.muted)
    readonly property bool micMuted: !!(Audio.source && Audio.source.audio && Audio.source.audio.muted)
    function toggleSink() { if (Audio.sink && Audio.sink.audio) Audio.sink.audio.muted = !Audio.sink.audio.muted; }
    function toggleMic() { if (Audio.source && Audio.source.audio) Audio.source.audio.muted = !Audio.source.audio.muted; }
}
