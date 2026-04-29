import QtQuick
import "../"

// Slide-in/out animation container for all popups.
//
// Universal behavior lives here — animation, hover-to-open,
// self-hover tracking, and close delay. Each popup just wires
// its own Popups.* bool into `open` and optionally into
// `triggerHovered`, then listens for `closeRequested`.
//
// Usage (click-only popup — e.g. ArchMenu):
//   PopupSlide {
//       id: slide
//       edge: "left"
//       open: Popups.archMenuOpen
//       // content
//   }
//
// Usage (hover popup — e.g. AudioPopup):
//   PopupSlide {
//       id: slide
//       edge: "right"
//       open: Popups.audioOpen
//       hoverEnabled:    true
//       triggerHovered:  Popups.audioTriggerHovered
//       onCloseRequested: Popups.audioOpen = false
//       // content
//   }
//
// Always bind PopupWindow.visible to slide.windowVisible.

Item {
    id: root

    // ── Required ──────────────────────────────────────────────────────────────
    property string edge: "left"    // "left" | "right" | "top" | "bottom"
    property bool   open: false     // the Popups.*Open bool for this popup

    // ── Hover-to-open (optional) ──────────────────────────────────────────────
    property bool hoverEnabled:   false
    property bool triggerHovered: false   // bind to Popups.*TriggerHovered

    // ── Universal timing — sourced from Popups singleton ──────────────────────
    property int slideDuration: Popups.slideDuration
    property int closeDelay:    Popups.hoverCloseDelay

    // ── Output ────────────────────────────────────────────────────────────────
    // Bind PopupWindow.visible to this
    property bool windowVisible: false

    // Emitted after closeDelay when hover leaves — popup sets its Popups.* bool
    signal closeRequested()

    // ── Internal ──────────────────────────────────────────────────────────────
    property bool _selfHovered: false

    // The popup should be visually open when:
    //   • its Popups bool is true, OR
    //   • hover is enabled and either the trigger or the popup itself is hovered
    readonly property bool _effectiveOpen:
        open || (hoverEnabled && (triggerHovered || _selfHovered))

    default property alias content: inner.data

    clip: true

    // ── State machine ─────────────────────────────────────────────────────────
    on_EffectiveOpenChanged: {
        if (_effectiveOpen) {
            hoverCloseTimer.stop()
            windowVisible = true
        } else {
            if (hoverEnabled) {
                // Delay so the user can move from trigger to popup without flicker
                hoverCloseTimer.restart()
            } else {
                slideCloseTimer.restart()
            }
        }
    }

    // Wait for slide-out to finish before hiding window (click-close path)
    Timer {
        id: slideCloseTimer
        interval: root.slideDuration + 20
        onTriggered: root.windowVisible = false
    }

    // Hover leave — wait closeDelay then emit closeRequested
    Timer {
        id: hoverCloseTimer
        interval: root.closeDelay
        onTriggered: {
            // Double-check hover is still gone before requesting close
            if (!root.triggerHovered && !root._selfHovered) {
                root.windowVisible = false
                root.closeRequested()
            }
        }
    }

    // ── Sliding item ──────────────────────────────────────────────────────────
    Item {
        id: inner
        width:  parent.width
        height: parent.height

        x: root._effectiveOpen ? 0 : (root.edge === "left"  ? -width  :
                                       root.edge === "right" ?  width  : 0)

        y: root._effectiveOpen ? 0 : (root.edge === "top"    ? -height :
                                       root.edge === "bottom" ?  height : 0)

        Behavior on x { NumberAnimation { duration: root.slideDuration; easing.type: Easing.OutCubic } }
        Behavior on y { NumberAnimation { duration: root.slideDuration; easing.type: Easing.OutCubic } }

        // Self-hover tracking — automatically available to all popups
        HoverHandler {
            onHoveredChanged: root._selfHovered = hovered
        }
    }
}
