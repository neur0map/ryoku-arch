import QtQuick
import "Singletons"

/**
 * Ryoku's island hover mark: a short orange underline that fades in beneath the
 * hovered icon and out when the pointer leaves. It is per-icon, so moving across
 * the status row crossfades in place rather than a bead flying between icons
 * (the inherited soul-bead motion this replaces). Drive `on` from the icon's own
 * hover state.
 */
Rectangle {
    property bool on: false
    property real s: 1

    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.bottom
    anchors.topMargin: 3 * s

    width: 14 * s
    height: 2 * s
    radius: height / 2
    color: Theme.brand
    opacity: on ? 1 : 0

    Behavior on opacity { NumberAnimation { duration: Motion.fast; easing.type: Motion.easeStandard } }
}
