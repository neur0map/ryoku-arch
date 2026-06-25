import QtQuick
import "Singletons"

/**
 * Host-side surface base for a plugin's content. Mirrors the pill's PillSurface
 * curtain: the plugin content lives at a FIXED open size inside a clip that
 * tracks the live (morphing) body, so a host can reveal/hide it by animating its
 * own width/height without the content reflowing or squishing mid-morph.
 *
 * A host (FramePopout, Island, ...) sets `s`, `openW`, `openH`, `shown` and
 * `openProgress` exactly as the pill does for its surfaces; the plugin's
 * content/Widget.qml is reparented into `slot` and lays out once at the open
 * size for the host's chosen density. The shell owns this base; plugins never
 * touch it.
 */
Item {
    id: surface

    property real s: 1
    property bool shown: false
    property real openProgress: 0
    property real openW: 0
    property real openH: 0

    property real mTop: 0
    property real mLeft: 0
    property real mRight: 0
    property real mBottom: 0

    // The plugin content item the host parented in (its content/Widget.qml root).
    default property alias data: contentInner.data

    enabled: shown
    opacity: shown ? Math.min(1, openProgress / 0.25) : 0
    visible: opacity > 0.01

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
}
