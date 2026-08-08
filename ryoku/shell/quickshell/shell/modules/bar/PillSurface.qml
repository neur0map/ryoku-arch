import QtQuick
import shell.services

// Shared base for the standard surface bodies (calendar, voice, keyring). A
// plain clipped Item that paints no background of its own: the host behind it
// owns the reveal and the fill, and this only holds the content at a FIXED open
// size inside a clip so the content lays out once and never reflows while the
// host reveals or hides it. The content is inset by the surface's own margins
// (scaled by `s`).
//
// host sets: open, s, openW, openH, shown, openProgress. surface sets its own
// margins. `active` mirrors `open` for onActiveChanged. requestClose()
// dismisses. Osd/Toast use a different lifecycle.
Item {
    id: surface

    property real s: 1
    property bool open: false

    // set by the host. `shown` = true while this surface is on screen: open,
    // and through the close until the host settles at rest. `openProgress` =
    // how open the host is right now (0 at rest, 1 fully open), so content
    // can't fade out of a still-open host or linger in a closing one.
    property bool shown: false
    property real openProgress: 0

    // surface open size, so the content holder is fixed at full size while the
    // host reveals it.
    property real openW: 0
    property real openH: 0

    property real mTop: 0
    property real mLeft: 0
    property real mRight: 0
    property real mBottom: 0

    signal requestClose()

    // Ame anchor. each surface declares the flame's form + dock point
    // (surface-local coords) for its open state; host maps the point into
    // its own space and feeds the active surface's pair to Ame. left
    // non-readonly so a deriving surface can re-bind. base default = off at
    // the centre.
    property string ameForm: "off"
    property point amePoint: Qt.point(width / 2, height / 2)

    readonly property bool active: open

    anchors.fill: parent
    anchors.topMargin: mTop * s
    anchors.leftMargin: mLeft * s
    anchors.rightMargin: mRight * s
    anchors.bottomMargin: mBottom * s

    enabled: open
    // gentle finishing fade tied to the host's live openProgress so it can't
    // run on its own timeline.
    opacity: shown ? Math.min(1, openProgress / 0.25) : 0
    visible: opacity > 0.01

    // Content lives at its FIXED open size inside a clip, so surface children
    // land in `contentInner` via the default alias, lay out once at full size
    // and never reflow while the host reveals them.
    Item {
        id: bodyClip
        anchors.fill: parent
        clip: true

        Item {
            id: contentInner
            width: Math.max(0, surface.openW - (surface.mLeft + surface.mRight) * surface.s)
            height: Math.max(0, surface.openH - (surface.mTop + surface.mBottom) * surface.s)
            x: Math.round((bodyClip.width - width) / 2)
            y: 0
        }
    }

    default property alias data: contentInner.data
}
