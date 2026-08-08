pragma ComponentBehavior: Bound

import QtQuick
import ".." as Menus
import shell.services

Item {
    id: root

    property real s: 1
    property bool open: false
    property var navigate: null
    property var closePanel: null

    // Opaque surface backing so the push covers the outgoing module (matches the
    // home tab); without it this transparent module ghosts the page behind it.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Menus.MenuNotifications {
        anchors.fill: parent
        anchors.margins: 12
        s: root.s
        open: root.open
        onRequestClose: if (root.closePanel) root.closePanel()
    }
}
