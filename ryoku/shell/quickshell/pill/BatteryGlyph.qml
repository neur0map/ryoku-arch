import QtQuick
import QtQuick.Shapes
import "Singletons"

// Battery cell glyph: a rounded body with a nub, filled to `frac` and tinted by
// state (low = vermilion, charging = ember, otherwise neutral). A bolt overlays
// while charging. Driven by the Battery singleton; every weight scales with `s`.
Item {
    id: root

    property real s: 1
    property real frac: 0
    property bool charging: false
    property bool low: false

    implicitWidth: 25 * s
    implicitHeight: 13 * s

    readonly property color tint: low ? Theme.vermLit : (charging ? Theme.flameGlow : Theme.subtle)

    Rectangle {
        id: bodyRect
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        width: 21 * root.s
        height: 12 * root.s
        radius: 3.5 * root.s
        color: "transparent"
        border.width: 1.4 * root.s
        border.color: Qt.alpha(root.tint, 0.55)

        Rectangle {
            anchors.left: parent.left
            anchors.leftMargin: 2 * root.s
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, (parent.width - 4 * root.s) * Math.max(0, Math.min(1, root.frac)))
            height: parent.height - 4 * root.s
            radius: 1.5 * root.s
            color: root.tint
            Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }
            Behavior on color { ColorAnimation { duration: 200 } }
        }
    }

    // Terminal nub.
    Rectangle {
        anchors.left: bodyRect.right
        anchors.leftMargin: 1 * root.s
        anchors.verticalCenter: parent.verticalCenter
        width: 2 * root.s
        height: 5 * root.s
        radius: 1 * root.s
        color: Qt.alpha(root.tint, 0.55)
    }

    // Charging bolt, centred on the cell.
    Shape {
        anchors.horizontalCenter: bodyRect.horizontalCenter
        anchors.verticalCenter: bodyRect.verticalCenter
        visible: root.charging
        width: 12 * root.s
        height: 12 * root.s
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            fillColor: Theme.cream
            strokeColor: Qt.alpha(Theme.cardBot, 0.7)
            strokeWidth: 0.6 * root.s
            scale: Qt.size(root.s, root.s)
            PathSvg { path: "M7 1.5 L3.2 6.8 H6 L5 10.5 L9 5 H6.2 Z" }
        }
    }
}
