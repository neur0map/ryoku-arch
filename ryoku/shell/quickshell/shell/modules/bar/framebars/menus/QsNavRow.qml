pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// A full-width sidebar navigation row: an icon disc, a label with live
// sub-state, and a trailing chevron. The whole face presses in and opens a
// detail page. The quiet-surface counterpart to QsTile, without the toggle.
Item {
    id: root

    property string icon: "circle"
    property string label: ""
    property string sub: ""

    signal activated()

    implicitHeight: 52

    // The resting fill composited over the panel surface, so the ink stays
    // legible on the wash (matching QsTile).
    readonly property color effBg: Theme.blend(
        Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06),
        Theme.effectiveSurface)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, face.containsMouse ? 0.10 : 0.06)
        border.width: 1
        border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)
        Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
        SumiEdge {}
    }

    MouseArea {
        id: face
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: 12
        spacing: 12

        Rectangle {
            id: iconDisc
            anchors.verticalCenter: parent.verticalCenter
            scale: face.pressed ? 0.86 : 1
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
            width: 34
            height: 34
            radius: 17
            color: Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
            MaterialIcon {
                anchors.centerIn: parent
                font.pixelSize: 18
                text: root.icon
                color: Theme.inkOn(root.effBg, Theme.onSurface, 3.0)
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - iconDisc.width - chevron.width - parent.spacing * 2
            spacing: 1
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.label
                color: Theme.inkOn(root.effBg, Theme.onSurface)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                visible: text.length > 0
                text: root.sub
                color: Theme.inkOn(root.effBg, Theme.onSurfaceVariant, 3.0)
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm - 2
            }
        }

        MaterialIcon {
            id: chevron
            anchors.verticalCenter: parent.verticalCenter
            font.pixelSize: 16
            text: "chevron_right"
            color: Theme.inkOn(root.effBg, Theme.onSurfaceVariant, 3.0)
        }
    }
}
