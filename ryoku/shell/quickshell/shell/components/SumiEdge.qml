import QtQuick
import shell.services

// The sumi edge: a 1px light line laid along a card's top edge, like the lit
// edge of layered paper. Inset by the corner radius so it never overshoots the
// rounded corners, and drawn over the card's own top border to brighten it. One
// quiet highlight, no glow and no blur. Place as a child of the card it lifts.
Rectangle {
    property real radius: Theme.radiusWidget

    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: radius
    anchors.rightMargin: radius
    height: 1
    color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
}
