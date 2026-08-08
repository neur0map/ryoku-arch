pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// Segmented choice row: equal-width options in one bordered track, the active
// one filled with the primary tint. Used for power profiles.
Rectangle {
    id: root

    property var options: []      // [{ id, label }]
    property string current: ""

    signal chose(string id)

    implicitHeight: 38
    radius: Theme.radiusWidget
    color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)

    Row {
        anchors.fill: parent
        anchors.margins: 4
        spacing: 4

        Repeater {
            model: root.options
            delegate: Rectangle {
                id: seg
                required property var modelData
                readonly property bool active: seg.modelData.id === root.current
                width: (parent.width - (root.options.length - 1) * 4) / Math.max(1, root.options.length)
                height: parent.height
                radius: Theme.radiusWidget - 4
                color: seg.active ? Theme.primary
                    : segTap.containsMouse
                        ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
                        : "transparent"
                Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
                Text {
                    anchors.centerIn: parent
                    text: seg.modelData.label
                    color: seg.active ? Theme.inkOn(Theme.primary, Theme.onPrimary) : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
                    font.family: Theme.fontPrimary
                    font.pixelSize: Theme.fontSm - 1
                    font.weight: seg.active ? Font.DemiBold : Font.Normal
                }
                MouseArea {
                    id: segTap
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.chose(seg.modelData.id)
                }
            }
        }
    }
}
