pragma ComponentBehavior: Bound

import QtQuick
import ".."
import shell.services
import "../../../components"

// A boxy head control shared by the card heads (scan, power, wifi toggle):
// hairline box, bone-plate while `active`, and an optional `spin` for a live
// scan. Reads the Theme directly.
Item {
    id: root

    property real s: 1
    property string glyph: ""
    property bool active: false
    property bool spin: false
    signal clicked()

    readonly property color ink: Theme.ink(Theme.effectiveSurface)
    readonly property color inkDim: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
    readonly property color line: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)

    implicitWidth: 21 * root.s
    implicitHeight: 18 * root.s

    Rectangle {
        anchors.fill: parent
        radius: 3 * root.s
        color: root.active ? Theme.inverseSurface
            : (hh.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.08) : "transparent")
        border.width: root.active ? 0 : Theme.borderWidth
        border.color: root.line
    }
    GlyphIcon {
        anchors.centerIn: parent
        width: 12.5 * root.s
        height: width
        name: root.glyph
        stroke: 1.8
        color: root.active ? Theme.inverseOnSurface : root.inkDim
        RotationAnimator on rotation {
            running: root.spin
            loops: Animation.Infinite
            from: 0; to: 360; duration: 1500
        }
    }
    HoverHandler { id: hh; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; onClicked: root.clicked() }
}
