import QtQuick
import "Singletons"

// a bar module that eases in (grows along the bar axis and fades) when it
// appears and eases out when it leaves, instead of snapping into place: music
// starting or stopping, a module toggling on. the content width is latched, so
// the width Behavior animates reliably in both directions (and when the content
// itself changes width, e.g. a new track title). `gap` folds the row spacing
// into the animated span, so nothing lingers when it collapses; host rows that
// use this set spacing 0. the content is clipped so it never overflows a
// neighbour mid-animation, and the island width -- and the frame lobe beneath
// it -- tracks this width, so the whole cluster resizes with it.
Item {
    id: reveal

    property real s: 1
    property bool shown: true
    property real gap: 0
    // drop out of a spaced row when closed (so no phantom row-spacing lingers).
    // a spacing-0 row keeps it laid out so its content stays measured.
    property bool dropWhenClosed: false
    default property alias content: holder.data

    // latch the measured content width: while collapsed the child may report 0,
    // so hold the last real width and animate to it on the next open.
    readonly property real liveW: holder.childrenRect.width
    property real measuredW: 0
    onLiveWChanged: if (liveW > 0.5) measuredW = liveW

    property bool ready: false
    Component.onCompleted: ready = true

    clip: true
    visible: dropWhenClosed ? (shown || width > 0.5) : true
    width: shown ? measuredW + gap : 0
    implicitWidth: width
    height: holder.childrenRect.height
    implicitHeight: height

    Behavior on width {
        enabled: reveal.ready
        NumberAnimation { duration: Motion.spatial; easing.type: Easing.OutCubic }
    }
    opacity: shown ? 1 : 0
    Behavior on opacity {
        enabled: reveal.ready
        NumberAnimation { duration: Motion.effects; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsCurve }
    }

    Item {
        id: holder
        x: reveal.gap
        y: 0
        width: childrenRect.width
        height: childrenRect.height
    }
}
