import QtQuick
import "Singletons"

// A horizontal slider with an ember-filled track and a round knob. Reports the
// value live (press and drag) via moved(value); the owner holds the value so the
// preview and the dirty state retune as the knob travels. Snaps to step when set.
Item {
    id: slider

    property real from: 0
    property real to: 1
    property real value: 0
    property real step: 0
    signal moved(real value)

    implicitWidth: 160
    implicitHeight: 22

    readonly property real knobR: 9
    readonly property real trackX: knobR
    readonly property real trackW: Math.max(1, width - 2 * knobR)
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    function valueAt(px) {
        var t = Math.max(0, Math.min(1, (px - trackX) / trackW));
        var v = from + t * (to - from);
        if (step > 0)
            v = Math.round(v / step) * step;
        return Math.max(from, Math.min(to, v));
    }

    Rectangle {
        id: track
        x: slider.trackX
        width: slider.trackW
        height: 4
        radius: 2
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.surfaceLo
        border.width: 1
        border.color: Theme.line

        Rectangle {
            width: slider.frac * parent.width
            height: parent.height
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0.0; color: Theme.emberDeep }
                GradientStop { position: 1.0; color: Theme.ember }
            }
        }
    }

    Rectangle {
        id: knob
        width: slider.knobR * 2
        height: slider.knobR * 2
        radius: width / 2
        x: slider.trackX + slider.frac * slider.trackW - slider.knobR
        anchors.verticalCenter: parent.verticalCenter
        color: ma.pressed || ma.containsMouse ? Theme.bright : Theme.cream
        border.width: 2
        border.color: Theme.ember
        scale: ma.pressed ? 1.14 : 1
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on scale { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        preventStealing: true
        onPressed: (m) => slider.moved(slider.valueAt(m.x))
        onPositionChanged: (m) => { if (pressed) slider.moved(slider.valueAt(m.x)); }
    }
}
