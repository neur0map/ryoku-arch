pragma ComponentBehavior: Bound

import QtQuick
import ".."
import shell.services
import "../../../components"

// A hairline mono chip shared by the popout cards. `act` makes it a tappable,
// hoverable control; `on` fills it to a bone plate for the selected state (an
// active power profile, the current codec). Reads the Theme directly so every
// card's chips match without threading colours through.
Item {
    id: root

    property real s: 1
    property string label: ""
    property string glyph: ""
    property bool act: false
    property bool on: false
    signal clicked()

    readonly property color ink: Theme.ink(Theme.effectiveSurface)
    readonly property color inkDim: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
    readonly property color line: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)

    implicitHeight: 18 * root.s
    implicitWidth: rowc.implicitWidth + 11 * root.s

    Rectangle {
        anchors.fill: parent
        radius: 3 * root.s
        color: root.on ? Theme.inverseSurface
            : (root.act && hh.hovered ? Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.10) : "transparent")
        border.width: root.on ? 0 : Theme.borderWidth
        border.color: root.line
    }
    Row {
        id: rowc
        anchors.centerIn: parent
        spacing: 3 * root.s
        GlyphIcon {
            visible: root.glyph.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: 9 * root.s
            height: width
            name: root.glyph
            stroke: 1.7
            color: root.on ? Theme.inverseOnSurface : root.inkDim
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: root.on ? Theme.inverseOnSurface : root.ink
            font.family: Theme.mono
            font.pixelSize: 9 * root.s
        }
    }
    HoverHandler { id: hh; enabled: root.act; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; enabled: root.act; onClicked: root.clicked() }
}
