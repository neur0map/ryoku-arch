pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services
import qs.modules.bar.popouts // Need to import this module so the Wrapper type is the same as others

Item {
    id: root

    required property ShellScreen screen
    required property real borderThickness

    // A horizontal bar (top/bottom) drops popouts DOWN from its inner edge, centred on
    // the hovered item's X; a vertical bar (left/right) slides them OUT, centred on its Y.
    // The parent (Panels) is already inset past the bar, so the bar-facing edge is parent's.
    readonly property string edge: BarDesign.edge
    readonly property bool horizontal: edge === "top" || edge === "bottom"

    readonly property alias content: content
    property real offsetScale: content.isDetached || content.hasCurrent ? 0 : 1

    // The spatial easing (expressiveDefaultSpatial, control point y=1.21) OVERSHOOTS
    // past its target, so on close offsetScale springs above 1.0 before settling.
    // Driving the morph straight off offsetScale would then push width below the
    // notch width and height negative on the last frames — the box springs PAST the
    // island and back (a corner-flicker), and the two separate width/height bindings
    // can latch a degenerate frame as visible. Cap the morph progress at 1 so the
    // close lands cleanly on the island with no past-the-corner bounce. The open
    // side (offsetScale dipping below 0) is left free, so the grow keeps its
    // expressive overshoot.
    readonly property real morphProg: Math.min(1, offsetScale)

    // Drive visibility off the animation progress, NOT the geometry — exactly like
    // the centre island/dashboard wrappers (`visible: offsetScale < 1`). The spatial
    // easing overshoots past its target, so on close offsetScale springs above 1.0
    // (width below the notch, height negative) before settling. A geometry gate
    // (`width > 0 && height > 0`) reads width and height as two separate bindings
    // that update independently on the overshoot frame, so it can latch that
    // degenerate half-state as visible for one frame — the corner flicker. An
    // offsetScale gate hides the whole overshoot region cleanly: the box simply
    // isn't shown once it has fully retracted, so the spring-past never renders.
    visible: offsetScale < 1
    clip: true

    // Horizontal (top/bottom): the popout is a drawer behind the island. The box
    // morphs out of the island — width from the notch's width to full, height from
    // 0 to full — and the content rides the box's BOTTOM edge (see the Wrapper
    // below), so the open slides the whole card down from behind the island and
    // the close slides it back up behind it, ending exactly on the idle island so
    // the merge is seamless. Holding full width and animating height alone left a
    // content-width band wider than the island through the whole close (visible
    // gap on the last frames); pinning the content to the box TOP made the close
    // read as the card deflating in place under the icons instead of retreating
    // behind the island. Horizontally the content stays pinned at openX in screen
    // space — re-centring it with the shrinking box dragged it sideways (the old
    // close squeeze). Vertical (left/right) keeps its sideways grow (away-axis
    // width).
    implicitWidth: root.horizontal ? content.currentNotchWidth + (content.implicitWidth - content.currentNotchWidth) * (1 - morphProg) : content.implicitWidth * (1 - morphProg)
    implicitHeight: root.horizontal ? content.implicitHeight * (1 - morphProg) : content.implicitHeight

    // Where the box sits when fully open (offsetScale 0) — the morph's far end.
    // The content is pinned here in screen space for the whole open/close morph so
    // the moving box edges clip it in place instead of dragging it toward the notch.
    readonly property real openX: {
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;
        const w = content.implicitWidth;
        const off = content.currentCenter - borderThickness - w / 2;
        const diff = parent.width - Math.floor(off + w);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    x: {
        if (!root.horizontal)
            return content.isDetached ? (parent.width - content.nonAnimWidth) / 2 : 0;
        if (content.isDetached)
            return (parent.width - content.nonAnimWidth) / 2;

        const w = implicitWidth;
        // The retract target is the island, and an edge island (left/right notch)
        // overlaps the frame's side-border stub — it runs to the screen edge, not
        // the content area's. Relax the content-area clamp by the border as the
        // box closes so the end state lands exactly on the island footprint;
        // clamping to the content area throughout stopped borderThickness short
        // of the island's outer edge, a visible step on the last frames. The
        // border strip is the same blob surface, so the overhang never shows.
        const over = borderThickness * Math.max(0, morphProg);
        const off = content.currentCenter - borderThickness - w / 2;
        const diff = parent.width + over - Math.floor(off + w);
        if (diff < 0)
            return off + diff;
        return Math.max(off, -over);
    }
    y: {
        if (root.horizontal)
            return content.isDetached ? (parent.height - content.nonAnimHeight) / 2 : 0;
        if (content.isDetached)
            return (parent.height - content.nonAnimHeight) / 2;

        const off = content.currentCenter - borderThickness - content.nonAnimHeight / 2;
        const diff = parent.height - Math.floor(off + content.nonAnimHeight);
        if (diff < 0)
            return off + diff;
        return Math.max(off, 0);
    }

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on x {
        // Horizontal docked: x is derived from the content width and re-centres on the
        // notch, and the width itself already animates (Wrapper's implicitWidth
        // Behavior), so x tracks it frame-by-frame; an x Behavior here would lag that
        // and jitter the box edge on icon-to-icon switches. The DETACHED branch is
        // different — its x is the centred float `(parent.width - nonAnimWidth)/2`,
        // which jumps when a popout is pinned into the window-info panel (isDetached
        // flips while the width animates separately), so animate x there to slide the
        // box to centre instead of teleporting. Vertical keeps its sideways slide.
        enabled: root.horizontal ? content.isDetached : true

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Behavior on y {
        enabled: root.horizontal ? true : root.offsetScale < 1

        Anim {
            duration: content.animLength
            easing: content.animCurve
        }
    }

    Wrapper {
        id: content

        screen: root.screen
        offsetScale: root.offsetScale

        anchors.verticalCenter: root.horizontal ? undefined : parent.verticalCenter
        anchors.left: root.horizontal ? undefined : parent.left
        anchors.leftMargin: root.horizontal ? 0 : (-implicitWidth - 5) * root.offsetScale
        // Horizontal: pinned in screen space at the fully-open position so the
        // morphing box clips the content in place instead of dragging it toward
        // the notch. Anchors can't express "stay put while my parent moves", so x
        // compensates for the box's own motion; while fully open this is exactly
        // 0 (centred), same as the old horizontalCenter.
        x: root.horizontal ? root.openX - root.x : 0
        // Horizontal: the card rides the box's bottom edge — its top slides up
        // past the clip (behind the bar) as the box collapses — so the close
        // reads as the drawer retreating BEHIND the island and the open as it
        // sliding out of the island's back, not as a card deflating in place
        // under the icons. While fully open the box is content-sized, so this is
        // 0 (the old top-pinned position) and icon-to-icon size changes animate
        // exactly as before.
        y: root.horizontal ? root.height - height : 0
    }
}
