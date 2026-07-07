pragma ComponentBehavior: Bound

import QtQuick
import ".."

// workspaces popout content: the workspace switcher (Super+Tab), grown from the
// bar edge. holds the WorkspacesSurface pinned open so the Popout blob does the
// reveal. pointer-only (drag is hand-tracked inside the surface); dismisses via
// the popout focus grab. requestClose bubbles up.
Item {
    id: root

    property real s: 1
    property bool open: false
    property string screenName: ""
    signal closeRequested()

    implicitWidth: ws.desiredW
    implicitHeight: ws.implicitHeight + 32 * root.s

    WorkspacesSurface {
        id: ws
        anchors.fill: parent
        s: root.s
        screenName: root.screenName
        open: true
        shown: true
        openProgress: 1
        openW: root.implicitWidth
        openH: root.implicitHeight
        onRequestClose: root.closeRequested()
    }
}
