import QtQuick
import "../.." as Pill
import shell.services
import "../../../../components"

// Square icon button for the sidebar header, footer, and page-back rows.
// `danger` warms the hover to the error tint for destructive session actions.
Rectangle {
    id: root

    property string icon: "circle"
    property string tip: ""
    property bool danger: false
    // Top-edge controls open their bubble downward so it never leaves the panel.
    property bool tipBelow: false
    // Bubble edge to pin to: "center" (default), "left" or "right".
    property string tipAlign: "center"

    signal clicked()

    implicitWidth: 38
    implicitHeight: 38
    radius: Theme.radiusWidget
    color: tap.containsMouse
        ? (root.danger
            ? Qt.rgba(Theme.error.r, Theme.error.g, Theme.error.b, 0.22)
            : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.12))
        : Qt.rgba(Theme.onSurface.r, Theme.onSurface.g, Theme.onSurface.b, 0.06)
    border.width: 1
    border.color: Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, tap.containsMouse ? 0.4 : 0.22)
    Behavior on color { ColorAnimation { duration: Motion.crossfade; easing.type: Motion.crossfadeCurve } }

    // Native press feel: the face dips under the pointer and springs back.
    scale: tap.pressed ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }

    MaterialIcon {
        anchors.centerIn: parent
        font.pixelSize: 18
        text: root.icon
        color: root.danger && tap.containsMouse ? Theme.inkOn(Theme.effectiveSurface, Theme.error, 3.0) : Theme.inkOn(Theme.effectiveSurface, Theme.onSurface, 3.0)
    }

    MouseArea {
        id: tap
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }

    QsTip {
        text: root.tip
        below: root.tipBelow
        align: root.tipAlign
        hovered: tap.containsMouse && !tap.pressed
    }
}
