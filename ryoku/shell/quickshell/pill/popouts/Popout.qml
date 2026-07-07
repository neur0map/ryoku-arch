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
//   Popout { group: blobGroup; frameThickness: 16; radius: Theme.radius; smoothing: 30
//            edge: "left"; openW: 220; openH: 200; Mixer {} }
Item {
    id: root

    required property var group
    required property real frameThickness
    property real radius: Theme.radius
    property real smoothing: 30
    property string edge: "left"          // "left" | "right" | "top" | "bottom"
    property string align: "center"       // "start" | "center" | "end" (along the edge)
    // when >= 0, centre the body at this coordinate along the edge (the host
    // hands the triggering module's centre here so the popout emerges from it,
    // like caelestia's currentCenter); < 0 falls back to `align`.
    property real alongCenter: -1
    property real openW: 220
    property real openH: 200
    // size tracks the content's implicit size (the mixer grows as its device
    // picker expands or a stream appears); melt rather than snap.
    Behavior on openW { NumberAnimation { duration: Motion.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
    Behavior on openH { NumberAnimation { duration: Motion.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve } }
    property real hoverW: 0                // hover-band span along the edge (0 = match body)
    property real hoverH: 0                // hover-band depth from the edge (0 = frameThickness)
    property real s: 1
    property bool pinned: false           // force open (IPC / inspection)
    // false = the popout never opens from an edge hover band; it opens only
    // when pinned (a bar module tap) and then stays while the body is hovered.
    // caelestia's power button is click-only like this; an edge band on a bar
    // edge would otherwise overlap the modules it sits behind.
    property bool hoverOpen: true
    // a bar module owns this popout: it drives this true while the module (not
    // an edge band) is hovered, and feeds `alongCenter` its own centre, so the
    // popout emerges from the module. this is caelestia's per-module ownership
    // (currentName/currentCenter) with a fixed module->popout mapping.
    property bool triggerHovered: false
    // hold the along-centre while the popout is open, so it stays put when the
    // pointer leaves the owning icon for the body. it's live while the icon is
    // the trigger (hover) or the popout is pinned (a click); held otherwise so
    // the close animation retracts at the icon, not a re-derived centre.
    property real heldAlong: -1
    onAlongCenterChanged: if (triggerHovered || pinned) heldAlong = alongCenter
    onTriggerHoveredChanged: if (triggerHovered) heldAlong = alongCenter
    onPinnedChanged: if (pinned) heldAlong = alongCenter
    readonly property real effectiveAlong: (triggerHovered || pinned) ? alongCenter : heldAlong

    readonly property bool atLeft: edge === "left"
    readonly property bool atRight: edge === "right"
    readonly property bool atTop: edge === "top"
    readonly property bool atBottom: edge === "bottom"
    readonly property bool vertical: atLeft || atRight   // body grows horizontally
    readonly property bool hovered: (hoverOpen && triggerHH.hovered) || triggerHovered || bodyHH.hovered
    // host gates this off while a centre surface is open or a window is
    // fullscreen, so an edge hover never fights a modal surface.
    property bool active: true
    readonly property bool shouldOpen: active && (hovered || pinned)

    // hover-intent close grace: hold the popout open this many ms after
    // shouldOpen drops, so crossing the ~2px blob-border rim just outside the
    // body's hover region never flickers it shut. 0 = close at once (clicks).
    property int closeDelay: 0
    property bool heldOpen: false
    onShouldOpenChanged: {
        if (shouldOpen) { closeGrace.stop(); heldOpen = true; }
        else if (closeDelay > 0) closeGrace.restart();
        else heldOpen = false;
    }
    Component.onCompleted: heldOpen = shouldOpen

    // 0 = closed (flush in border), 1 = open.
    property real prog: 0

    anchors.fill: parent

    // edge position (cross-axis): start/center/end, with an inset so the body
    // never sits flush in a corner.
    readonly property real edgeInset: frameThickness + 12 * s
    function alignPos(span, sz) {
        if (effectiveAlong >= 0)
            return Math.max(edgeInset, Math.min(span - sz - edgeInset, effectiveAlong - sz / 2));
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
    readonly property real triggerW: !hoverOpen ? 0 : (vertical ? frameThickness : bandSpan)
    readonly property real triggerH: !hoverOpen ? 0 : (vertical ? bandSpan : frameThickness)
    readonly property real triggerX: atLeft ? 0
                                   : atRight ? (width - frameThickness)
                                   : (alongX + (openW - bandSpan) / 2)
    readonly property real triggerY: atTop ? 0
                                   : atBottom ? (height - frameThickness)
                                   : (alongY + (openH - bandSpan) / 2)

    states: State {
        name: "open"
        when: root.heldOpen
        PropertyChanges { root.prog: 1 }
    }
    transitions: [
        Transition {
            to: "open"
            NumberAnimation {
                property: "prog"
                duration: Motion.spatial
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.spatialCurve
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

    Timer { id: closeGrace; interval: root.closeDelay; onTriggered: root.heldOpen = false }

    // blob body = a BlobRect in the shared group. it anchors at the outer frame
    // edge and grows inward, exactly like shell.qml's pillBlob at the top: the
    // edge-side corners are zeroed so the body reads as the frame swelling open
    // -- no separate rounded bottom, no gap -- and a neck of the full frame
    // thickness + smoothing reaches PAST the body's outer face into the border
    // field, so smooth-min welds body and frame into one continuous edge. the
    // content clip stays inset above the band; the bar renders on top of it.
    BlobRect {
        id: bodyBlob
        readonly property real reach: root.frameThickness + root.smoothing
        readonly property real neckW: root.vertical ? reach : 0
        readonly property real neckH: root.vertical ? 0 : reach
        group: root.group
        // edge-side corners flush (fused into the frame border), inner corners
        // rounded -- so the body is continuous with the frame edge it grows from.
        topLeftRadius: (root.atTop || root.atLeft) ? 0 : root.radius
        topRightRadius: (root.atTop || root.atRight) ? 0 : root.radius
        bottomLeftRadius: (root.atBottom || root.atLeft) ? 0 : root.radius
        bottomRightRadius: (root.atBottom || root.atRight) ? 0 : root.radius
        deformScale: 0.000015
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
        opacity: root.heldOpen ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Motion.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsCurve } }

        HoverHandler { id: bodyHH }

        Item {
            id: contentInner
            width: root.openW
            height: root.openH
            x: root.atRight ? (bodyClip.width - root.openW) : 0
            y: root.atBottom ? (bodyClip.height - root.openH) : 0
            transform: Matrix4x4 { matrix: bodyBlob.deformMatrix }
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
