pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Blobs
import "../Singletons"

// surface popout that grows out of a frame edge (left/right/top/bottom) on
// hover and melts back into the border through the SHARED blob field. joins
// the pill's `group` (same BlobGroup as the frame border + centre island), so
// a popout reads as the frame swelling open at that edge, like the pill does
// at top-centre. shell.qml unions `triggerX/Y/W/H` and `bodyX/Y/W/H` into the
// overlay input mask.
//
// opening = a curtain: body grows inward from the border (a clip widens), so
// the fixed-size content reveals edge-first without ever resizing. close eases
// cleanly into the border with no overshoot, so the body never re-grows under
// a pointer that just left and pins it open. blob body + neck into the border
// + reveal all live here; each popup file only supplies its content. `align`
// slides the body along the edge (start/center/end).
//
//   Popout { group: blobGroup; frameThickness: 16; radius: 16; smoothing: 30
//            edge: "left"; openW: 220; openH: 200; Mixer {} }
Item {
    id: root

    required property var group
    required property real frameThickness
    property real radius: 16
    property real smoothing: 30
    property string edge: "left"          // "left" | "right" | "top" | "bottom"
    property string align: "center"       // "start" | "center" | "end" (along the edge)
    property real openW: 220
    property real openH: 200
    // size tracks the content's implicit size (the mixer grows as its device
    // picker expands or a stream appears); melt rather than snap.
    Behavior on openW { NumberAnimation { duration: Motion.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.morphCurve } }
    Behavior on openH { NumberAnimation { duration: Motion.morph; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.morphCurve } }
    property real hoverW: 0                // hover-band span along the edge (0 = match body)
    property real hoverH: 0                // hover-band depth from the edge (0 = frameThickness)
    property real s: 1
    property bool pinned: false           // force open (IPC / inspection)

    readonly property bool atLeft: edge === "left"
    readonly property bool atRight: edge === "right"
    readonly property bool atTop: edge === "top"
    readonly property bool atBottom: edge === "bottom"
    readonly property bool vertical: atLeft || atRight   // body grows horizontally
    readonly property bool hovered: triggerHH.hovered || bodyHH.hovered
    // host gates this off while a centre surface is open or a window is
    // fullscreen, so an edge hover never fights a modal surface.
    property bool active: true
    readonly property bool shouldOpen: active && (hovered || pinned)

    // 0 = closed (flush in border), 1 = open.
    property real prog: 0

    anchors.fill: parent

    // edge position (cross-axis): start/center/end, with an inset so the body
    // never sits flush in a corner.
    readonly property real edgeInset: frameThickness + 12 * s
    function alignPos(span, sz) {
        return align === "start" ? edgeInset
             : align === "end" ? span - sz - edgeInset
             : (span - sz) / 2;
    }
    readonly property real alongX: alignPos(width, openW)
    readonly property real alongY: alignPos(height, openH)

    // body geometry in window coords; grows inward from the border.
    readonly property real curW: vertical ? Math.max(0, openW * prog) : openW
    readonly property real curH: vertical ? openH : Math.max(0, openH * prog)
    readonly property real bodyX: atLeft ? frameThickness
                                 : atRight ? (width - frameThickness - curW)
                                 : alongX
    readonly property real bodyY: atTop ? frameThickness
                                 : atBottom ? (height - frameThickness - curH)
                                 : alongY
    readonly property real bodyW: curW
    readonly property real bodyH: curH

    // hover trigger = the frame border itself: a thin strip of the frame next
    // to the popout, `frameThickness` deep (same pixels the mixer/power popouts
    // use). spans the frame next to the body but capped so it's a small,
    // deliberate hot-spot, not a tall invisible line that opens before the
    // pointer even hits the frame.
    readonly property real bandSpan: Math.min(vertical ? openH : openW, 220 * s)
    readonly property real triggerW: vertical ? frameThickness : bandSpan
    readonly property real triggerH: vertical ? bandSpan : frameThickness
    readonly property real triggerX: atLeft ? 0
                                   : atRight ? (width - frameThickness)
                                   : (alongX + (openW - bandSpan) / 2)
    readonly property real triggerY: atTop ? 0
                                   : atBottom ? (height - frameThickness)
                                   : (alongY + (openH - bandSpan) / 2)

    states: State {
        name: "open"
        when: root.shouldOpen
        PropertyChanges { root.prog: 1 }
    }
    transitions: [
        Transition {
            to: "open"
            NumberAnimation {
                property: "prog"
                duration: Motion.morph
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.morphCurve
            }
        },
        Transition {
            from: "open"
            NumberAnimation {
                property: "prog"
                duration: Motion.morph
                easing.type: Easing.OutCubic
            }
        }
    ]

    // blob body = a BlobRect in the shared group, tracking the content clip and
    // reaching a neck past it into the border so smooth-min fuses them. neck
    // clamped to the body's own extent so it retracts cleanly on close, and
    // points back toward the edge the body grows from.
    BlobRect {
        readonly property real reach: root.frameThickness + root.smoothing
        readonly property real neckW: root.vertical ? Math.max(0, Math.min(reach, root.bodyW)) : 0
        readonly property real neckH: root.vertical ? 0 : Math.max(0, Math.min(reach, root.bodyH))
        group: root.group
        radius: root.radius
        deformScale: 0.0006
        x: root.bodyX - (root.atLeft ? neckW : 0)
        y: root.bodyY - (root.atTop ? neckH : 0)
        implicitWidth: root.bodyW > 0 ? root.bodyW + neckW : 0
        implicitHeight: root.bodyH > 0 ? root.bodyH + neckH : 0
    }

    // content at full size, revealed by a widening clip anchored to the border
    // side -> curtain reveals edge-first; content never reflows.
    Item {
        id: bodyClip
        x: root.bodyX
        y: root.bodyY
        width: root.bodyW
        height: root.bodyH
        clip: true
        visible: root.prog > 0.004
        opacity: Math.max(0, Math.min(1, (root.prog - 0.15) / 0.55))

        HoverHandler { id: bodyHH }

        Item {
            id: contentInner
            width: root.openW
            height: root.openH
            x: root.atRight ? (bodyClip.width - root.openW) : 0
            y: root.atBottom ? (bodyClip.height - root.openH) : 0
        }
    }

    default property alias data: contentInner.data

    Item {
        id: trigger
        x: root.triggerX
        y: root.triggerY
        width: root.triggerW
        height: root.triggerH
        HoverHandler { id: triggerHH }
    }
}
