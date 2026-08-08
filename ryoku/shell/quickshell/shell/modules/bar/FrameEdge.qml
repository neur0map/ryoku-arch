pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import shell.services

// One of the four background reservation surfaces of the frame. It paints
// nothing and takes no input; its exclusive zone reserves the revealed bar's
// thickness plus the frame border so tiled windows clear the bar. A hidden or
// empty-collapsed bar reserves nothing, releasing the edge. Every bar and menu
// is content inside the single ryoku-frame overlay, never here. The four edges
// carry the whole screen reservation so the overlay can span the output with
// exclusiveZone -1 and still let a bar hide without unmapping the frame.
PanelWindow {
    id: frameEdge

    required property string edge          // "top" | "bottom" | "left" | "right"
    required property real reserve         // target exclusive zone in px, 0 = released
    readonly property bool horizontal: edge === "top" || edge === "bottom"

    // Reserve and surface size animate together, so a reveal slides the edge in
    // and a hide slides it out instead of snapping. It matches the measured
    // ease-out-cubic over 250 ms of the edge reservation reveal.
    property real zone: reserve
    Behavior on zone {
        NumberAnimation { duration: Motion.barReveal; easing.type: Motion.barRevealCurve }
    }

    color: "transparent"
    WlrLayershell.layer: WlrLayer.Background
    WlrLayershell.namespace: "ryoku-frame-edge"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Math.round(zone)

    // Anchor sets from contract 01 sec 1: horizontal edges span the full width
    // (both side anchors), vertical edges span the height left by the top and
    // bottom reservations. Each edge omits only its opposite edge.
    anchors {
        top: edge !== "bottom"
        bottom: edge !== "top"
        left: edge !== "right"
        right: edge !== "left"
    }
    // Never unmap. The reservation stack order is fixed at map time and the
    // exclusive-zone arrange gives corners to whoever reserves first, so the
    // four edges MUST map in a fixed order (top, bottom, left, right from
    // shell.qml) for the horizontal edges to own the corners and the vertical
    // ones to inset between them. Unmapping a collapsed edge and remapping it on
    // reveal reorders the stack (the largest target crosses the map threshold
    // first), which inverts the insets. So the surface stays mapped at a 1 px
    // floor and only its exclusive zone drops to 0 when the bar hides.
    implicitWidth: horizontal ? 0 : Math.max(1, Math.round(zone))
    implicitHeight: horizontal ? Math.max(1, Math.round(zone)) : 0
    visible: true

    mask: Region {}
}
