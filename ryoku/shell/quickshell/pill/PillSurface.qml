import QtQuick
import "Singletons"

/**
 * Shared morph-surface base for the pill's standard surfaces. The surface fills
 * the pill body inset by its margins (scaled by `s`); its content lives at a FIXED
 * open size inside a clip that tracks the live morphing body, so the island shape
 * reveals and hides the content like a curtain and it never resizes or squishes
 * (mirroring the edge popouts). The host sets `open`, `s`, `openW`, `openH`,
 * `shown`, `openProgress` (and `morphCloseness`); the surface sets its own margins.
 * `active` mirrors `open` for `onActiveChanged` hooks. `requestClose()` dismisses.
 * Osd and Toast use a different lifecycle and do not derive from this base.
 */
Item {
    id: surface

    property real s: 1
    property bool open: false
    property real morphCloseness: 1

    // Set by the pill. `shown` is true while this surface owns the island: open,
    // and through the close morph until the pill settles back at rest. `openProgress`
    // is how open the island actually is right now (0 at rest, 1 fully open),
    // derived from its live width, so content can never fade out of a still-open
    // island nor linger in a closing one.
    property bool shown: false
    property real openProgress: 0

    // The surface's open size (from the pill's surfaceSize), so the content holder
    // can be fixed at full size while the body clips it during the morph.
    property real openW: 0
    property real openH: 0

    property real mTop: 0
    property real mLeft: 0
    property real mRight: 0
    property real mBottom: 0

    signal requestClose()

    /**
     * Ame anchor. Each surface declares the flame's form and dock point (in
     * surface-local coords) for its open state; the host maps the point into
     * pill space and feeds the active surface's pair to Ame. Left non-readonly
     * so a deriving surface can re-bind. Base default is off at the centre.
     */
    property string ameForm: "off"
    property point amePoint: Qt.point(width / 2, height / 2)

    readonly property bool active: open

    anchors.fill: parent
    anchors.topMargin: mTop * s
    anchors.leftMargin: mLeft * s
    anchors.rightMargin: mRight * s
    anchors.bottomMargin: mBottom * s

    enabled: open
    // A gentle finishing fade on top of the clip reveal, tied to the same live
    // openProgress so it never runs on its own timeline.
    opacity: shown ? Math.min(1, openProgress / 0.25) : 0
    visible: opacity > 0.01

    // Ride the blob: the content lives at its FIXED open size inside a clip that
    // tracks the live (morphing) body, so the island shape reveals and hides it
    // like a curtain rather than the content resizing and squishing as the pill
    // grows or shrinks (this mirrors the edge popouts). Surface children land in
    // `contentInner` via the default alias, so they lay out once at full size and
    // never reflow during the morph.
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
