pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// One sidebar slider row: the shared HFader (icon tap = mute, live peak on
// audio nodes) with an optional chevron that opens the matching device page.
Item {
    id: root

    property alias icon: fader.icon
    property alias value: fader.value
    property alias valueLabel: fader.valueLabel
    property alias muted: fader.muted
    property alias peakNode: fader.peakNode
    property alias peakEnabled: fader.peakEnabled
    property bool lit: false
    property bool hasPage: false

    signal moved(real v)
    signal iconTapped()
    signal pageRequested()

    implicitHeight: 40

    HFader {
        id: fader
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: chevron.visible ? chevron.left : parent.right
        anchors.rightMargin: chevron.visible ? 6 : 0
        lit: root.lit
        onMoved: v => root.moved(v)
        onIconTapped: root.iconTapped()
    }

    Rectangle {
        id: chevron
        visible: root.hasPage
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 26
        height: 30
        radius: Theme.radiusWidget - 4
        color: pageTap.containsMouse
            ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12)
            : "transparent"
        MaterialIcon {
            anchors.centerIn: parent
            font.pixelSize: 16
            text: "chevron_right"
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurfaceVariant, 3.0)
        }
        MouseArea {
            id: pageTap
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pageRequested()
        }
        scale: pageTap.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    }
}
