import QtQuick
import shell.services

// Pill toggle: tile bg off, terracotta on, cream knob slides. Shared by the
// link surface and the WLAN/BT drill-ins.
Rectangle {
    id: toggle

    property real s: 1
    property bool on: false
    signal toggled()

    width: 28 * s
    height: 16 * s
    radius: 999
    color: on ? Theme.primary : Theme.surfaceContainerHigh
    border.width: on ? 0 : 1
    border.color: Theme.outline

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 10 * toggle.s
        height: 10 * toggle.s
        radius: width / 2
        color: Theme.onSurface
        x: toggle.on ? toggle.width - width - 3 * toggle.s : 3 * toggle.s
        Behavior on x { NumberAnimation { duration: Motion.fast } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
}
