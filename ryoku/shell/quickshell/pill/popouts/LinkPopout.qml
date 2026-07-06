pragma ComponentBehavior: Bound

import QtQuick
import ".."

// link popout content: the deep wifi/bluetooth surface (Super+N / status icons),
// grown from the bar edge. holds the Link surface (a PillSurface) pinned open so
// the Popout blob does the reveal. a keyboard popout (wifi password entry); the
// overlay grabs the keyboard for it. requestClose bubbles up to close.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal closeRequested()

    implicitWidth: link.desiredW
    implicitHeight: link.implicitHeight + 26 * root.s

    // consume clicks on empty body so they don't fall through to the backdrop
    // and dismiss the popout; the surface's own controls sit on top.
    MouseArea { anchors.fill: parent }

    Link {
        id: link
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
