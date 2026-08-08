pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// The shared card action: a bone-plate primary (Connect / Turn on / Scan) or,
// with `destructive`, a hairline-outlined word (Forget). Sizes to its label but
// a caller may set `width` for a full-width plate. Honours the built-in
// `enabled` for the dim/uninteractive state.
Item {
    id: root

    property real s: 1
    property string label: ""
    property bool destructive: false
    signal clicked()

    readonly property color ink: Theme.ink(Theme.effectiveSurface)
    readonly property color line: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)

    implicitHeight: 25 * root.s
    implicitWidth: lbl.implicitWidth + 28 * root.s

    Rectangle {
        anchors.fill: parent
        radius: 4 * root.s
        color: root.destructive ? "transparent" : Theme.inverseSurface
        border.width: root.destructive ? Theme.borderWidth : 0
        border.color: root.line
        opacity: root.enabled ? (hh.hovered ? 0.9 : 1) : 0.4
    }
    Text {
        id: lbl
        anchors.centerIn: parent
        text: root.label
        color: root.destructive ? root.ink : Theme.inverseOnSurface
        font.family: Theme.fontPrimary
        font.pixelSize: 11 * root.s
        font.weight: Font.Bold
    }
    HoverHandler { id: hh; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
    MouseArea { anchors.fill: parent; enabled: root.enabled; onClicked: root.clicked() }
}
