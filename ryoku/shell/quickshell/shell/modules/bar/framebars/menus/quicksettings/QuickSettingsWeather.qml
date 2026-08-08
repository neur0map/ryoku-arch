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

    // Opaque surface backing so the incoming push covers the outgoing module
    // (the sidebar page push slides the previous one only part-way off); without
    // it this transparent module ghosts the page behind it. Matches the home tab.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: weather.implicitHeight + 24
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Menus.MenuWeather {
            id: weather
            x: 12
            y: 12
            width: parent.width - 24
            s: root.s
            open: root.open
        }
    }
}
