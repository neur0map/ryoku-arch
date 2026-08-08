pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// A detail line shared by the "!" panels: a dim label with a right-aligned mono
// value, or -- with `toggle` -- a boxy switch. The caller sets `width`.
Item {
    id: root

    property real s: 1
    property string label: ""
    property string value: ""
    property bool toggle: false
    property bool on: false
    signal toggled()

    readonly property color ink: Theme.ink(Theme.effectiveSurface)
    readonly property color inkDim: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
    readonly property color line: Qt.rgba(root.ink.r, root.ink.g, root.ink.b, 0.14)

    implicitHeight: 19 * root.s

    Text {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        color: root.inkDim
        font.family: Theme.fontPrimary
        font.pixelSize: 10 * root.s
    }
    Text {
        visible: !root.toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: root.value
        color: root.ink
        font.family: Theme.mono
        font.pixelSize: 10 * root.s
        elide: Text.ElideLeft
        width: Math.min(implicitWidth, root.width * 0.6)
        horizontalAlignment: Text.AlignRight
    }
    Rectangle {
        visible: root.toggle
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 26 * root.s
        height: 14 * root.s
        radius: 3 * root.s
        color: root.on ? Theme.inverseSurface : "transparent"
        border.width: root.on ? 0 : Theme.borderWidth
        border.color: root.line
        Rectangle {
            width: 9 * root.s
            height: width
            radius: 2 * root.s
            color: root.on ? Theme.inverseOnSurface : root.inkDim
            anchors.verticalCenter: parent.verticalCenter
            x: root.on ? parent.width - width - 2.5 * root.s : 2.5 * root.s
            Behavior on x { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.toggled() }
    }
}
