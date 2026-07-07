import QtQuick
import "Singletons"

// the module container both reference skins share: a fully rounded pill on
// the band (caelestia's m3surfaceContainer, noctalia's capsule), with the
// caelestia StateLayer feel on interaction: an 8% overlay lifts on hover and
// a soft ripple blooms from the press point. content centres; the pill hugs
// it plus padding on the main axis.
Item {
    id: mod

    property real s: 1
    property bool vertical: false
    property real padX: 12 * s
    property real padY: 10 * s
    default property alias content: slot.data
    property bool interactive: true
    property bool filled: true  // a control pill; false = a bare mark (the logo), hover still lifts
    readonly property alias hovered: hoverArea.containsMouse

    signal tapped()
    signal wheeled(int steps)

    implicitWidth: vertical ? width : slot.implicitWidth + 2 * padX
    implicitHeight: vertical ? slot.implicitHeight + 2 * padY : height

    Rectangle {
        id: base
        anchors.fill: parent
        radius: Math.min(width, height) / 2
        color: filled ? Theme.tileBg : "transparent"
        clip: true

        // caelestia StateLayer: hover overlay at 0.08, press ripple at 0.1.
        Rectangle {
            anchors.fill: parent
            radius: base.radius
            color: Theme.cream
            opacity: hoverArea.containsMouse && mod.interactive ? 0.08 : 0
            Behavior on opacity { NumberAnimation { duration: Motion.hover; easing.type: Easing.OutCubic } }
        }
        Rectangle {
            id: ripple
            property real cx: base.width / 2
            property real cy: base.height / 2
            x: cx - width / 2
            y: cy - width / 2
            height: width
            radius: width / 2
            color: Theme.cream
            opacity: 0
            width: 0

            ParallelAnimation {
                id: rippleAnim
                NumberAnimation { target: ripple; property: "width"; from: 0; to: Math.max(base.width, base.height) * 2.6; duration: Motion.spatial; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectsSlowCurve }
                SequentialAnimation {
                    NumberAnimation { target: ripple; property: "opacity"; to: 0.1; duration: 60 }
                    NumberAnimation { target: ripple; property: "opacity"; to: 0; duration: Motion.effectsSlow; easing.type: Easing.OutCubic }
                }
            }
        }
    }

    // single-root content: the module hugs its implicit size.
    Item {
        id: slot
        anchors.centerIn: parent
        implicitWidth: children.length > 0 ? children[0].implicitWidth : 0
        implicitHeight: children.length > 0 ? children[0].implicitHeight : 0
        width: implicitWidth
        height: implicitHeight
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: mod.interactive
        cursorShape: Qt.PointingHandCursor
        onPressed: (e) => {
            ripple.cx = e.x;
            ripple.cy = e.y;
            rippleAnim.restart();
        }
        onClicked: mod.tapped()
        onWheel: (w) => mod.wheeled(w.angleDelta.y > 0 ? 1 : -1)
    }
}
