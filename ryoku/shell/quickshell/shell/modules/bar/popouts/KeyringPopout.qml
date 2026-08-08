pragma ComponentBehavior: Bound

import QtQuick
import ".."

// keyring popout content: the secret-service password prompt, grown from the bar
// edge. holds the KeyringSurface pinned open so the Popout blob does the reveal.
// a keyboard popout (password fields); the overlay grabs the keyboard for it.
// requestClose bubbles up, and dismissing cancels the prompt (see shell.qml).
Item {
    id: root

    property real s: 1
    property bool open: false
    signal closeRequested()

    implicitWidth: 380 * root.s
    implicitHeight: keyring.implicitHeight + 32 * root.s

    // consume clicks on empty body so they don't fall through to the backdrop
    // and dismiss the prompt; the surface's own fields sit on top.
    MouseArea { anchors.fill: parent }

    KeyringSurface {
        id: keyring
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
