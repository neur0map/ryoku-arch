pragma ComponentBehavior: Bound

import QtQuick
import ".."

// voice popout content: the Voxtype dictation overlay, grown from the bar edge.
// holds the VoiceSurface pinned open so the Popout blob does the reveal. it
// grabs NOTHING -- no keyboard, no focus grab -- so dictation lands in the
// focused app, not here; the daemon shows/hides it. requestClose bubbles up.
Item {
    id: root

    property real s: 1
    property bool open: false
    signal closeRequested()

    implicitWidth: 320 * root.s
    implicitHeight: voice.implicitHeight + 26 * root.s

    VoiceSurface {
        id: voice
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
