pragma ComponentBehavior: Bound

import QtQuick
import "../../../popouts" as Popouts
import shell.services

// The Capture tab of the quick-settings panel: the Super+S screenshot/record
// surface embedded bare (skin off, no popout card) into the module rail, right
// after Weather. Mirrors QuickSettingsWeather: an opaque surface backing under a
// Flickable that scrolls the content when the panel is shorter than it.
Item {
    id: root

    property real s: 1
    property bool open: false
    property var navigate: null
    property var closePanel: null

    // Opaque backing so the incoming push covers the outgoing module cleanly.
    Rectangle {
        anchors.fill: parent
        color: Theme.surface
    }

    Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: capture.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height

        Popouts.CapturePopout {
            id: capture
            width: parent.width
            s: root.s * 1.4
            open: root.open
            skin: false
        }
    }
}
