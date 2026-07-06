pragma ComponentBehavior: Bound

import QtQuick
import ".."

// clipboard popout content: the clipboard search + history surface opened from
// Super+V, grown from the bar edge. holds the Clipboard surface (a PillSurface)
// pinned statically open so the Popout blob does the reveal. a bare transparent
// Item; the Popout blob behind it IS the surface. keyboard focus comes from the
// overlay grabbing it for this (a kbPopout); requestClose bubbles up so Enter /
// a paste closes the popout.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal closeRequested()

    implicitWidth: 360 * root.s
    implicitHeight: 332 * root.s

    // consume clicks on empty areas of the body so they don't fall through to
    // the overlay backdrop and dismiss the popout (the surface's own controls
    // sit on top and take their clicks first).
    MouseArea { anchors.fill: parent }

    Clipboard {
        anchors.fill: parent
        s: root.s
        open: true
        shown: true
        openProgress: 1
        openW: root.implicitWidth
        openH: root.implicitHeight
        onRequestClose: root.closeRequested()
    }
}
