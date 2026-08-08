pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// One quick-settings toggle tile: icon in a state circle, label + live
// sub-state, whole face toggles, the chevron (when a detail page exists)
// navigates. Active tiles fill with the primary tint so state reads at a
// glance; everything else stays quiet surface.
Item {
    id: root

    property string icon: "circle"
    property string label: ""
    property string sub: ""
    property bool on: false
    property bool hasPage: false
    property string pageTip: ""

    signal toggled()
    signal pageRequested()

    implicitHeight: 64

    // The effective background the tile's ink sits on: the resting tile fill
    // (soft primary tint when on, soft on-surface wash when off) composited
    // over the panel's effective surface, so labels stay legible on the tint.
    readonly property color effBg: Theme.blend(
        root.on ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.20)
                : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06),
        Theme.effectiveSurface)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: root.on
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, face.containsMouse ? 0.26 : 0.20)
            : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, face.containsMouse ? 0.10 : 0.06)
        border.width: 1
        border.color: root.on
            ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.55)
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, 0.30)
        Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
        SumiEdge {}
    }

    MouseArea {
        id: face
        anchors.fill: parent
        anchors.rightMargin: root.hasPage ? 34 : 0
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.toggled()
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: parent.right
        anchors.rightMargin: root.hasPage ? 34 : 12
        spacing: 10

        Rectangle {
            id: iconDisc
            anchors.verticalCenter: parent.verticalCenter
            scale: face.pressed ? 0.86 : 1
            Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
            width: 34
            height: 34
            radius: 17
            color: root.on ? Theme.primary
                           : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.10)
            Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }
            MaterialIcon {
                anchors.centerIn: parent
                font.pixelSize: 18
                fill: root.on ? 1 : 0
                text: root.icon
                color: root.on ? Theme.inkOn(Theme.primary, Theme.onPrimary, 3.0)
                               : Theme.inkOn(root.effBg, Theme.onSurface, 3.0)
            }
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - iconDisc.width - parent.spacing
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
    }

    // Detail-page affordance: its own hit region so a chevron tap never toggles.
    Rectangle {
        visible: root.hasPage
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.margins: 6
        width: 26
        radius: Theme.radiusWidget - 4
        color: pageTap.containsMouse
            ? Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12)
            : "transparent"
        scale: pageTap.pressed ? 0.9 : 1
        Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
        MaterialIcon {
            anchors.centerIn: parent
            font.pixelSize: 16
            text: "chevron_right"
            color: Theme.inkOn(root.effBg, Theme.onSurfaceVariant, 3.0)
        }
        MouseArea {
            id: pageTap
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.pageRequested()
        }
        QsTip {
            text: root.pageTip
            align: "right"
            hovered: pageTap.containsMouse && !pageTap.pressed
        }
    }
}
