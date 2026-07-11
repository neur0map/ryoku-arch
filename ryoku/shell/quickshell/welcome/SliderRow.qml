pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Labeled slider with a live readout: ember-filled track, round knob. `moved` fires
// continuously and drives the readout/knob (the owner holds the value); `released`
// fires once when the drag ends, so the owner commits the change exactly once (a
// file write or a compositor reload), never per-pixel.
Item {
    id: root

    property string label: ""
    property string unit: ""
    property real from: 0
    property real to: 1
    property real step: 1
    property real value: 0
    signal moved(real value)
    signal released(real value)

    implicitWidth: 320
    implicitHeight: 46

    readonly property real knobR: 9
    readonly property real trackX: knobR
    readonly property real trackW: Math.max(1, slot.width - 2 * knobR)
    readonly property real frac: to > from ? Math.max(0, Math.min(1, (value - from) / (to - from))) : 0

    function valueAt(px) {
        var tt = Math.max(0, Math.min(1, (px - trackX) / trackW));
        var v = from + tt * (to - from);
        if (step > 0)
            v = Math.round(v / step) * step;
        return Math.max(from, Math.min(to, v));
    }

    Text {
        id: lbl
        anchors.left: parent.left
        anchors.top: parent.top
        text: root.label
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 13
        font.weight: Font.Medium
    }

    Text {
        anchors.right: parent.right
        anchors.baseline: lbl.baseline
        text: Math.round(root.value) + (root.unit.length ? (" " + root.unit) : "")
        color: Theme.bright
        font.family: Theme.mono
        font.pixelSize: 12
        font.weight: Font.DemiBold
    }

    Item {
        id: slot
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 22

        Rectangle {
            id: track
            x: root.trackX
            width: root.trackW
            height: 4
            radius: Theme.radius
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.surfaceLo
            border.width: 1
            border.color: Theme.line

            Rectangle {
                width: root.frac * parent.width
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
            width: root.knobR * 2
            height: root.knobR * 2
            radius: width / 2
            x: root.trackX + root.frac * root.trackW - root.knobR
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
            onPressed: (m) => root.moved(root.valueAt(m.x))
            onPositionChanged: (m) => { if (pressed) root.moved(root.valueAt(m.x)); }
            onReleased: (m) => root.released(root.valueAt(m.x))
        }
    }
}
