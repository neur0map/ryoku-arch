pragma ComponentBehavior: Bound

import QtQuick
import "../../../../components"
import shell.services

// Quick-settings launch button: opens the main quick-settings menu on left
// click. Shows the Ryoku brand mark (user decision): the same slot carries the
// distro mark in the reference, and the mark is what tells the two shells
// apart at a glance. Geometry stays the reference 16px icon box.
Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    implicitWidth: btn.implicitWidth
    implicitHeight: btn.implicitHeight

    RailButton {
        id: btn
        anchors.centerIn: parent
        edge: root.edge
        scale: root.scale
        onClicked: root.menuRequested("quick-settings", Qt.rect(0, 0, root.width, root.height))

        // Sized off the button's glyph box, so the brand mark tracks every other
        // rail icon instead of shrinking with a thin bar on its own.
        Item {
            width: btn.glyphPx
            height: btn.glyphPx
            BrandMark {
                anchors.centerIn: parent
                size: btn.glyphPx * (15 / Theme.iconSm)
                color: Theme.onSurface
            }
        }
    }
}
