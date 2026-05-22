pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.components
import qs.services

LazyLoader {
    id: loader

    activeAsync: Keybinds.visible

    FloatingWindow {
        id: win

        implicitWidth: 1080
        implicitHeight: 720
        minimumSize.width: 860
        minimumSize.height: 560
        color: Colours.tPalette.m3surface
        title: qsTr("Ryoku Keybinds")

        onVisibleChanged: {
            if (!visible)
                Keybinds.close();
        }

        Content {
            anchors.fill: parent
            onClose: win.destroy()
        }

        Behavior on color {
            CAnim {}
        }
    }
}
