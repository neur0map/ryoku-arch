pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// One bar edge: a fixed-thickness band pinned to its screen edge, holding the
// three zones. It creates no surface (it is content inside the frame overlay).
// A hidden bar slides its content off the screen edge; a 1px hover strip stays
// (exposed by the overlay input mask), so pointer proximity reveals the bar as
// an overlay without re-reserving the edge (contract 02 sec 4).
Item {
    id: root

    required property string edge
    required property var rail
    required property var style
    // Reveal/reserve baseline for this edge (from the shared reveal model);
    // hover reveals the bar on top of this without touching the reserve.
    required property bool revealed
    property Component delegate: null

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    // An empty bar renders nothing: no band, no slab, no hover slide. Only the
    // frame chrome's own 1px surface + 2px border shows on that edge.
    readonly property int itemCount: horizontal
        ? (rail.start || []).length + (rail.center || []).length + (rail.end || []).length
        : (rail.top || []).length + (rail.center || []).length + (rail.bottom || []).length
    readonly property real band: itemCount > 0 ? rail.size : 0
    // reveal_child = revealed || hovered (contract 02 sec 4).
    readonly property bool shown: revealed || bandHover.hovered

    // Inter-widget gap inside a zone, scaled with the band so a thin bar keeps
    // the same visual rhythm as a full one. Without it the fixed-size buttons
    // butt edge to edge with no breathing room.
    readonly property real gap: 12 * Math.min(1, (rail.size || 48) / 48)

    // Insets at the two ends of the rail's long axis so a rail clears the
    // perpendicular rails' bands at the shared corners instead of overlapping
    // their widgets. Horizontal rails own the corners (0); vertical rails inset
    // by the top and bottom bands, fitting between them (set by Bar.qml).
    property real leadInset: 0
    property real tailInset: 0

    // Fixed-thickness band pinned to its edge, spanning the perpendicular axis.
    width: horizontal ? parent.width : band
    height: horizontal ? band : parent.height
    anchors.top: edge === "top" ? parent.top : undefined
    anchors.bottom: edge === "bottom" ? parent.bottom : undefined
    anchors.left: edge === "left" ? parent.left : undefined
    anchors.right: edge === "right" ? parent.right : undefined

    // Hover proximity over the band (only the edge strip is reachable while the
    // bar is hidden, since the overlay mask exposes just that 1px there).
    HoverHandler { id: bandHover }

    // Content slides off the screen edge when hidden and back in when shown;
    // the reveal envelope is the measured bar reveal (250 ms ease-out-cubic).
    Item {
        id: content
        width: root.width
        height: root.height
        x: (!root.horizontal && !root.shown) ? (root.edge === "left" ? -root.band : root.band) : 0
        y: (root.horizontal && !root.shown) ? (root.edge === "top" ? -root.band : root.band) : 0
        Behavior on x { NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve } }
        Behavior on y { NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve } }

        // The band visual is the frame chrome's job (FrameChrome paints every
        // edge's surface and border in one pass); the rail is pure content.
        // The three zones share the WHOLE bar rather than a rigid third each: a
        // start group packs from the leading edge, a centre group sits on the
        // bar's midpoint, an end group packs from the trailing edge. Each spans
        // only its own widgets, so a heavy group (the nine status icons on a
        // side rail) uses the full length instead of overrunning a fixed slice
        // and clipping off the far end. The zones overlay the bar; only their
        // widgets take input, so empty stretches fall through to the ones below.
        Item {
            visible: root.horizontal
            // Content sits between the adjacent edge bands' surface slivers:
            // measured first item centre 18.8, last 1179.8 on the reference.
            x: root.leadInset + 1
            width: parent.width - root.leadInset - root.tailInset - 3
            height: parent.height

            RailZone { id: hStart; anchors.fill: parent; ids: root.rail.start; horizontal: true; align: "start"; spacing: root.gap; delegate: root.delegate }
            // `center` is the one zone key both orientations read, so gate it to
            // this one; the hidden orientation must instantiate no widgets.
            RailZone {
                anchors.fill: parent; ids: root.horizontal ? root.rail.center : []; horizontal: true; align: "center"; spacing: root.gap; delegate: root.delegate
                leadExtent: hStart.implicitWidth
                tailExtent: hEnd.implicitWidth
                // above the end zones: on a rail too short for all three, the
                // dock overlaps its neighbours instead of hiding under them.
                z: 1
            }
            RailZone { id: hEnd; anchors.fill: parent; ids: root.rail.end; horizontal: true; align: "end"; spacing: root.gap; delegate: root.delegate }
        }

        Item {
            visible: !root.horizontal
            y: root.leadInset + 1
            width: parent.width
            height: parent.height - root.leadInset - root.tailInset - 3

            RailZone { id: vTop; anchors.fill: parent; ids: root.rail.top; horizontal: false; align: "start"; spacing: root.gap; delegate: root.delegate }
            RailZone {
                anchors.fill: parent; ids: root.horizontal ? [] : root.rail.center; horizontal: false; align: "center"; spacing: root.gap; delegate: root.delegate
                leadExtent: vTop.implicitHeight
                tailExtent: vBottom.implicitHeight
                z: 1
            }
            RailZone { id: vBottom; anchors.fill: parent; ids: root.rail.bottom; horizontal: false; align: "end"; spacing: root.gap; delegate: root.delegate }
        }
    }
}
