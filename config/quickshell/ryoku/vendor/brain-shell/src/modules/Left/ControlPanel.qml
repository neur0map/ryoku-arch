import QtQuick
import Quickshell
import "../../"

// Ryoku Patch 8: Arch logo replaced with Ryoku monogram (kanji 力 from
// logo-mark.svg) in canonical Ryoku Greek-Noir orange. ArchMenu trigger
// behavior preserved for when ArchMenu is activated in Spec 8.
// Rewritten as a self-contained Rectangle + Image + MouseArea instead
// of using IconBtn (which is text-only). See vendor/brain-shell/UPSTREAM.md.
Rectangle {
    id: root
    width:  24
    height: 24
    radius: 4
    color:  hover.hovered ? Theme.active : "transparent"

    Image {
        anchors.centerIn: parent
        source:      "file://" + Quickshell.env("HOME") + "/.local/share/ryoku/logo-mark.svg"
        sourceSize:  Qt.size(20, 20)
        width:       20
        height:      20
        fillMode:    Image.PreserveAspectFit
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            var next = !Popups.archMenuOpen
            Popups.closeAll()
            Popups.archMenuOpen = next
        }
    }
}
