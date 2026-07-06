pragma ComponentBehavior: Bound

import QtQuick
import ".."

// inbox popout content: the notification centre (the bar's bell), grown from the
// bar edge. holds the Inbox surface (a PillSurface) pinned open so the Popout
// blob does the reveal. pointer-only (no keyboard), so it dismisses via the
// popout focus grab like the status popouts. requestClose bubbles up to close.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal closeRequested()

    implicitWidth: 340 * root.s
    implicitHeight: inbox.implicitHeight + 26 * root.s

    Inbox {
        id: inbox
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
