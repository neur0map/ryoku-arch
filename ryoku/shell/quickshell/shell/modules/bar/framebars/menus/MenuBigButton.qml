pragma ComponentBehavior: Bound

import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// Shared primary capture tile (contract 09 sec 2): a primary-filled 116x72 tile
// carrying a 32px icon above a 14px label, both in the on-primary tone. Hover
// lifts the fill to the accent-light tint; disabled dims fill and content to 38%
// and drops the pointer cursor. The screenshot modes and the record modes are
// all built from this one tile, so it lives with the shared menu primitives.
Item {
    id: root

    property string iconName: ""
    property string label: ""
    signal clicked()

    implicitWidth: 116
    implicitHeight: 72

    // Content tone resolved once through the enabled state so a child never
    // recomputes the on-primary / dimmed pair.
    readonly property color content: root.enabled ? Theme.onPrimary
        : Qt.rgba(Theme.onPrimary.r, Theme.onPrimary.g, Theme.onPrimary.b, 0.38)

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWidget
        color: !root.enabled ? Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.38)
            : hover.hovered ? Theme.vermLit
            : Theme.primary
        Behavior on color { ColorAnimation { duration: Motion.thumbHover; easing.type: Motion.easeType; easing.bezierCurve: Motion.easeCurve } }

        Column {
            anchors.centerIn: parent
            spacing: Theme.paddingSm

            MaterialIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconLg
                height: Theme.iconLg
                font.pixelSize: Theme.iconLg
                text: root.iconName
                color: root.content
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.label
                color: root.content
                font.family: Theme.fontPrimary
                font.pixelSize: Theme.fontSm
            }
        }
    }

    HoverHandler { id: hover; enabled: root.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: root.enabled; onTapped: root.clicked() }
}
