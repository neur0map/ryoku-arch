pragma ComponentBehavior: Bound

import QtQuick

// The session-action widgets: lock, logout and shutdown. Each is a static glyph
// that fires its direct action. Contract 04 sec 3.2.
Item {
    id: root

    required property string actionId
    required property string edge
    required property real scale
    signal actionRequested(string id)

    readonly property var glyphs: ({
        "lock": "system-lock-screen",
        "logout": "system-log-out",
        "shutdown": "system-shutdown"
    })

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        icon: root.glyphs[root.actionId] || "application-x-executable"
        onClicked: root.actionRequested(root.actionId)
    }
}
