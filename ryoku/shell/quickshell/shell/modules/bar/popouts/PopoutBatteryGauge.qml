pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// A boxy battery pictogram: hairline body, a proportional fill that eases as the
// level moves, and a terminal nub. `frac` 0..1; `warn` reds the fill. Sizes to
// `gw` x `gh` so the hero can render it large and a device chip small.
Item {
    id: root

    property real s: 1
    property real frac: 0
    property bool warn: false
    property real gw: 20 * root.s
    property real gh: 11 * root.s

    readonly property color ink: Theme.ink(Theme.effectiveSurface)
    readonly property color inkDim: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
    readonly property color fillColor: root.warn ? Theme.error : root.ink

    implicitWidth: root.gw
    implicitHeight: root.gh

    Rectangle {
        width: parent.width - 2 * root.s
        height: parent.height
        radius: 1.5 * root.s
        color: "transparent"
        border.width: Theme.borderWidth
        border.color: root.inkDim
        Rectangle {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: 1.5 * root.s
            width: Math.max(0, (parent.width - 3 * root.s) * Math.max(0, Math.min(1, root.frac)))
            height: parent.height - 3 * root.s
            radius: 1 * root.s
            color: root.fillColor
            Behavior on width { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
        }
    }
    Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 1.5 * root.s
        height: parent.height * 0.42
        radius: 1 * root.s
        color: root.inkDim
    }
}
