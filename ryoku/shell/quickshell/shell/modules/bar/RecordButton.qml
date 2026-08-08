pragma ComponentBehavior: Bound

import QtQuick
import shell.services
import "../../components"

// flat icon button for the recording HUD: tint carries the state (vermilion
// stop, dim mute), hover lights the tile.
Rectangle {
    id: btn

    property real s: 1
    property string glyph: ""
    property color tint: Theme.onSurfaceVariant
    signal tapped()

    width: 26 * s
    height: 26 * s
    radius: 7 * s
    color: hov.hovered ? Theme.frameBg : "transparent"
    Behavior on color { ColorAnimation { duration: Motion.fast } }

    GlyphIcon {
        anchors.centerIn: parent
        width: 15 * btn.s
        height: 15 * btn.s
        name: btn.glyph
        color: btn.tint
        stroke: 1.7
    }

    HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: btn.tapped() }
}
