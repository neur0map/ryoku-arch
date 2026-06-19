pragma ComponentBehavior: Bound

import QtQuick
import Ryoku.Blobs
import "../Singletons"

/**
 * A surface popout that grows out of a vertical frame edge (left or right) on
 * hover and melts into the border through the SHARED blob field. It joins the
 * pill's `group` (the same BlobGroup as the frame border and the centre island),
 * so a popout reads as the frame swelling open at that edge, the same way the
 * pill does at top-centre. shell.qml unions `triggerX/Y/W/H` and `bodyX/Y/W/H`
 * into the overlay input mask.
 *
 * Opening is a curtain: the body grows inward from the border (a clip widens), so
 * the fixed-size content reveals edge-first without ever resizing. The close eases
 * cleanly into the border with no overshoot, so the body never re-grows under a
 * pointer that just left and sticks the popout open. The blob body, the neck into
 * the border, and the reveal all live here;
 * each popup file only supplies its content.
 *
 *   Popout { group: blobGroup; frameThickness: 16; radius: 16; smoothing: 30
 *            edge: "left"; openW: 220; openH: 200; Mixer {} }
 */
Item {
    id: root

    required property var group
    required property real frameThickness
    property real radius: 16
    property real smoothing: 30
    property string edge: "left"          // "left" | "right"
    property real openW: 220
    property real openH: 200
    property real s: 1
    property bool pinned: false           // force open (IPC / inspection)

    readonly property bool atLeft: edge === "left"
    readonly property bool hovered: triggerHH.hovered || bodyHH.hovered
    // Host gates this off while a centre surface is open or a window is
    // fullscreen, so an edge hover never fights a modal surface.
    property bool active: true
    readonly property bool shouldOpen: active && (hovered || pinned)

    // 0 = closed (flush into the border), 1 = open.
    property real prog: 0

    anchors.fill: parent

    // Body geometry in window coordinates; the body grows inward from the border.
    readonly property real cy: Math.round((height - openH) / 2)
    readonly property real curW: Math.max(0, openW * prog)
    readonly property real bodyX: atLeft ? frameThickness : (width - frameThickness - curW)
    readonly property real bodyY: cy
    readonly property real bodyW: curW
    readonly property real bodyH: openH

    // Hover trigger: the border segment beside the body, pixel-perfect to the
    // frame (exactly `frameThickness` deep), spanning the body height so the
    // pointer never falls into a dead gap on the way in.
    readonly property real triggerW: frameThickness
    readonly property real triggerH: openH
    readonly property real triggerX: atLeft ? 0 : (width - frameThickness)
    readonly property real triggerY: cy

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

    // Blob body: a BlobRect in the shared group, tracking the content clip and
    // reaching a neck past it into the border so the smooth-min fuses them. The
    // neck is clamped to the body's own width so it retracts cleanly on close.
    BlobRect {
        readonly property real reach: root.frameThickness + root.smoothing
        readonly property real neck: Math.max(0, Math.min(reach, root.bodyW))
        group: root.group
        radius: root.radius
        deformScale: 0.0006
        x: root.bodyX - (root.atLeft ? neck : 0)
        y: root.bodyY
        implicitWidth: root.bodyW > 0 ? root.bodyW + neck : 0
        implicitHeight: root.bodyH
    }

    // The content, full size, revealed by a widening clip anchored to the border
    // side so the curtain reveals edge-first; the content never reflows.
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
            x: root.atLeft ? 0 : (bodyClip.width - root.openW)
            y: 0
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
