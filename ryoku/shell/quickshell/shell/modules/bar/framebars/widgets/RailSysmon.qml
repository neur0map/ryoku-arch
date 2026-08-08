pragma ComponentBehavior: Bound

import QtQuick
import "../../../../components"

// System monitor widget: a CPU glyph on the rail that opens the system monitor
// card (the "sysmon" surface) on click. The icon is static -- the live stats
// poll only while the card is open, so an idle rail costs nothing.
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
        onClicked: root.menuRequested("sysmon", Qt.rect(btn.x, btn.y, btn.width, btn.height))

        GlyphIcon {
            // glyphScale, not scale: this gauge sits in a row of Material glyphs
            // and has to hold the same size they now do on a thin rail.
            width: 17 * btn.glyphScale
            height: 17 * btn.glyphScale
            name: "cpu"
            color: btn.iconColor
            stroke: 1.8
        }
    }
}
