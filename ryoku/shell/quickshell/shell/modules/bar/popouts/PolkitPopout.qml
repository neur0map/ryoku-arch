pragma ComponentBehavior: Bound

import QtQuick
import ".."

// polkit popout content: the administrator-password prompt, grown from the bar
// edge. Holds PolkitSurface pinned open so the Popout blob does the reveal, the
// same shape the keyring prompt uses. A keyboard popout; the overlay grabs the
// keyboard for it, and dismissing cancels the authentication (see shell.qml).
Item {
    id: root

    property real s: 1
    property bool open: false
    signal closeRequested()

    implicitWidth: 380 * root.s
    implicitHeight: polkit.implicitHeight + 32 * root.s

    // consume clicks on empty body so they don't fall through to the backdrop
    // and cancel the prompt; the surface's own field sits on top.
    MouseArea { anchors.fill: parent }

    PolkitSurface {
        id: polkit
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
