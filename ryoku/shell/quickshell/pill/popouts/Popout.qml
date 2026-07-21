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
    // full-height sidebar: the body fills the frame top-to-bottom and fuses into
    // the top AND bottom borders (not only the edge it grows from), so it reads
    // as the whole side of the frame swelling open, no gap at either end. only
    // meaningful for a left/right edge.
    property bool fullSpan: false
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
    onPinnedChanged: {
        if (pinned) { heldAlong = alongCenter; return; }
        // a deliberate unpin (keybind re-toggle, tap, close button, Escape) shuts
        // at once: the closeDelay grace only debounces a hover-leave across the
        // blob rim, so a pin release skips it -- even under the pointer, an
        // unpinned popout must not hold open on body hover. an active edge/corner
        // hover gesture still holds it, so a clickless open is unaffected.
        if (!triggerHovered) { closeGrace.stop(); heldOpen = false; }
    }
    readonly property real effectiveAlong: (triggerHovered || pinned) ? alongCenter : heldAlong

    // hold the size for the whole close the same way heldAlong holds the
    // centre: content tears down at prog 0.5 and its implicit size collapses,
    // so a live openW/openH would chase it mid-melt through the overshooting
    // spatial Behavior, dipping the body past flush before the terminal
    // zero-size frame pops it back. latched, the melt is one monotonic retract.
    property real heldW: 0
    property real heldH: 0
    onOpenWChanged: if (heldOpen) heldW = openW
    onOpenHChanged: if (heldOpen) heldH = openH
    readonly property real bodyOpenW: heldOpen ? openW : heldW
    readonly property real bodyOpenH: heldOpen ? openH : heldH

    readonly property bool atLeft: edge === "left"
    readonly property bool atRight: edge === "right"
    readonly property bool atTop: edge === "top"
    readonly property bool atBottom: edge === "bottom"
    readonly property bool vertical: atLeft || atRight   // body grows horizontally
    readonly property bool spanning: fullSpan && vertical
    // the body-hover hold only applies to hover-driven popouts (edge band or a
    // bar module): a click-pinned popout must close the moment it's unpinned
    // (close button, Escape, keybind re-toggle), even under the pointer.
    readonly property bool hovered: (hoverOpen && triggerHH.hovered) || triggerHovered
        || (bodyHH.hovered && (hoverOpen || closeDelay > 0))
    // host gates this off while a centre surface is open or a window is
    // fullscreen, so an edge hover never fights a modal surface.
    property bool active: true
    readonly property bool shouldOpen: active && (hovered || pinned)

    // hover-intent close grace: hold the popout open this many ms after
    // shouldOpen drops, so crossing the ~2px blob-border rim just outside the
    // body's hover region never flickers it shut. 0 = close at once (clicks).
    property int closeDelay: 0
    property bool heldOpen: false
    onHeldOpenChanged: if (heldOpen) { heldW = openW; heldH = openH }
    onShouldOpenChanged: {
        if (shouldOpen) { closeGrace.stop(); heldOpen = true; }
        else if (closeDelay > 0) closeGrace.restart();
        else heldOpen = false;
    }
    Component.onCompleted: heldOpen = shouldOpen

    // 0 = closed (flush in border), 1 = open.
    property real prog: 0

    anchors.fill: parent

    // along-axis position: start / center / end (or a clamped alongCenter),
    // inset from the perpendicular frame wall so the body never sits in the
    // corner. the wall is the on-screen frame lip (frameBorder - 50, the same
    // the frame border and barVisibleH use), NOT the bar's full thickness --
    // using frameThickness held a corner popout a whole band's width off.
    readonly property real edgeInset: Math.max(0, Config.frameBorder - 50) + 12 * s
    function alignPos(span, sz) {
        if (effectiveAlong >= 0)
            return Math.max(edgeInset, Math.min(span - sz - edgeInset, effectiveAlong - sz / 2));
        return align === "start" ? edgeInset
             : align === "end" ? span - sz - edgeInset
             : (span - sz) / 2;
    }
    readonly property real alongX: alignPos(width, bodyOpenW)
    readonly property real alongY: alignPos(height, bodyOpenH)
    // hover band placement tracks the live content size: a never-opened
    // popout has no latched size yet, and its band must still be hoverable.
    readonly property real trigAlongX: alignPos(width, openW)
    readonly property real trigAlongY: alignPos(height, openH)

    // a popout clamped against a side wall fuses INTO it rather than floating an
    // inset off it: the body edge reaches the screen edge with a neck through the
    // blob field and that corner squares off, so a corner popout reads as the
    // frame swelling out of the corner -- no gap, the same way the growing edge
    // fuses into the bar. top/bottom bar only (along-axis is X); a centred
    // popout is never at a wall, so it stays put. the flat/floating skins
    // (noWeld) have no frame wall to fuse into, so they never hug: a module
    // popout near the screen edge stays inset instead of clipping off it.
    readonly property bool hugLeft: !noWeld && !vertical && width > 0 && bodyOpenW > 0 && alongX <= edgeInset + 0.5
    readonly property bool hugRight: !noWeld && !vertical && width > 0 && bodyOpenW > 0 && alongX >= width - bodyOpenW - edgeInset - 0.5

    // body geometry in window coords; grows inward from the border.
    readonly property real curW: vertical ? Math.max(0, bodyOpenW * prog)
                                 : (dipHost && !heldOpen) ? Math.max(0, bodyOpenW * prog) : bodyOpenW
    readonly property real curH: vertical ? ((dipHost && !heldOpen) ? Math.max(0, bodyOpenH * prog) : bodyOpenH) : Math.max(0, bodyOpenH * prog)
    readonly property real bodyX: atLeft ? frameThickness
                                 : atRight ? (width - frameThickness - curW)
                                 : hugRight ? (width - curW)
                                 : hugLeft ? 0
                                 : alongX + (dipHost && !heldOpen ? (bodyOpenW - curW) / 2 : 0)
    readonly property real bodyY: spanning ? 0
                                 : atTop ? frameThickness
                                 : atBottom ? (height - frameThickness - curH)
                                 : alongY + (dipHost && !heldOpen ? (bodyOpenH - curH) / 2 : 0)
    readonly property real bodyW: curW
    readonly property real bodyH: spanning ? height : curH

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
                                   : (trigAlongX + (openW - bandSpan) / 2)
    readonly property real triggerY: atTop ? 0
                                   : atBottom ? (height - frameThickness)
                                   : (trigAlongY + (openH - bandSpan) / 2)

    // input-mask rect: the resting open geometry, gone the moment the close
    // starts. prog never appears here, so a melt tick cannot recommit the
    // wayland input region 60 times a second (the close-time frame drops), and
    // a melting body stops eating clicks the instant it is dismissed.
    readonly property real maskX: atLeft ? frameThickness
                                : atRight ? (width - frameThickness - bodyOpenW)
                                : hugRight ? (width - bodyOpenW)
                                : hugLeft ? 0
                                : alongX
    readonly property real maskY: spanning ? 0
                                : atTop ? frameThickness
                                : atBottom ? (height - frameThickness - bodyOpenH)
                                : alongY
    readonly property real maskW: heldOpen ? bodyOpenW : 0
    readonly property real maskH: heldOpen ? bodyOpenH : 0

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
    // near close, retract the blob's inner face one smoothing-depth into the
    // border: the smooth-min fillet holds the fused edge ~k(1-1/sqrt(2)) proud
    // of the band until the shape is deleted at zero size, which reads as the
    // melt stalling and then snapping flush in one frame. buried >= smoothing,
    // the fillet residual is already zero when the shape drops out.
    readonly property real burial: (1 - Math.max(0, Math.min(1, prog))) * smoothing

    // triptych and nacre keep a hairline top that dips between the three lobes. a
    // popout there fills the band across its own span while open (bodyBlob's
    // neck does that, so the frame swells under it while the other clusters
    // keep their dips). on close it does not deflate in place and leave a wide
    // empty band to collapse: it narrows back toward the module it grew from
    // (curW tracks the melt, centred on the trigger), so the band retracts into
    // that lobe and the dips return around it -- the popout melts back into the
    // frame it came out of. the flat iNiR skins (inir/aurora/angel) and atoll's
    // floating islands narrow-melt too: they have no swelled band, so a
    // full-width neck would hang over the bar.
    readonly property bool dipHost: Config.barStyle === "delos" || (!vertical && (root.noWeld || ["triptych", "nacre", "inir", "aurora", "angel", "atoll"].includes(Config.barStyle)))

    // a welded popout grows a neck into the frame-border blob and, on close, buries
    // that inner face one smoothing-depth in, so the border reads as swallowing it.
    // with the frame off there is no border: the neck would bridge empty space and
    // flicker as it drops out (the close bump), so noWeld drops the neck and the
    // corner hug. it KEEPS the burial, though -- retracting the inner face still
    // makes the blob hit zero size before it can strand a metaball fillet, so a
    // floating island melts shut clean with no shrinking nub. noWeld = any skin
    // with the frame off (border gone), plus atoll -- both its variants float
    // their islands over the wallpaper (ilyamiro round, ryoku square), so the
    // frame never swells a band for them to weld into.
    readonly property bool noWeld: Config.barStyle === "atoll" || !Config.frameEnabled

    BlobRect {
        id: bodyBlob
        readonly property real reach: root.frameThickness + root.smoothing
        readonly property real neckW: (root.vertical && !root.noWeld) ? reach : 0
        readonly property real neckH: (!root.vertical && !root.noWeld) ? reach : 0
        readonly property real hugNeckL: (root.hugLeft && !root.noWeld) ? reach : 0
        readonly property real hugNeckR: (root.hugRight && !root.noWeld) ? reach : 0
        group: root.group
        // a closed popout (prog 0) still sits in the shared blob field at its
        // resting origin, and even at zero implicit size it pulls a smooth-min
        // nub onto whatever popout is open at the same centre -- every popout
        // shares `alongCenter`, so they stack at one point. that nub is invisible
        // on transparent popout content (the blob IS the surface there) but reads
        // as a dark bump on an opaque one (the power panel's wallpaper hero). so
        // drop the body from the field until it actually opens, matching bodyClip.
        visible: root.prog > 0.004
        // noWeld has no frame band to weld into (frame off, or atoll's floating
        // islands), so it grows no neck -- but it stays a blob and still buries its
        // inner face on close (see `burial`), so it hits zero size cleanly instead
        // of stranding a shrinking fillet nub. it melts shut toward the bar it grew
        // from, the same retract a welded body makes into the frame border.
        // edge-side corners flush (fused into the frame border), inner corners
        // rounded -- so the body is continuous with the frame edge it grows from.
        topLeftRadius: (root.atTop || root.atLeft || root.hugLeft || root.spanning) ? 0 : root.radius
        topRightRadius: (root.atTop || root.atRight || root.hugRight || root.spanning) ? 0 : root.radius
        bottomLeftRadius: (root.atBottom || root.atLeft || root.hugLeft || root.spanning) ? 0 : root.radius
        bottomRightRadius: (root.atBottom || root.atRight || root.hugRight || root.spanning) ? 0 : root.radius
        deformScale: 0.000015
        // no border pocket: the melt buries this rect in the band, and a sink
        // would recede the frame line around it until the zero-size drop-out
        // snaps it back (the close-time "dips past flush then pops" artifact)
        sinks: false
        x: root.bodyX - (root.atLeft ? neckW : 0) - hugNeckL + (root.atRight ? root.burial : 0)
        // a full-span sidebar overshoots both screen edges so its silhouette
        // outline clips off-screen (like the frame's own -50 oversize); only the
        // inner edge shows a line. the content clip below stays on-screen.
        y: root.spanning ? -60 : (root.bodyY - (root.atTop ? neckH : 0) + (root.atBottom ? root.burial : 0))
        implicitWidth: root.bodyW <= 0 ? 0 : Math.max(0, root.bodyW + neckW + hugNeckL + hugNeckR - (root.vertical ? root.burial : 0))
        implicitHeight: root.spanning ? (root.height + 120) : (root.bodyH <= 0 ? 0 : Math.max(0, root.bodyH + neckH - (root.vertical ? 0 : root.burial)))
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
