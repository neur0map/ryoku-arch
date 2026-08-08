pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Shapes
import shell.services

// A 270-degree ring gauge for the system monitor: a dim track arc and a coloured
// value arc that eases to `value` (0..1), with a mono readout in the centre and
// a label under it. Eye-candy but idle-cheap -- the Shape only re-renders while
// the value animates, never on a timer.
Item {
    id: root

    property real value: 0
    property color ringColor: Theme.primary
    property string label: ""
    property string readout: ""
    property real s: 1

    readonly property real dim: 62 * root.s

    // the drawn sweep eases behind the raw value so a poll step glides in.
    property real anim: 0
    Behavior on anim { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    onValueChanged: root.anim = Math.max(0, Math.min(1, root.value))
    Component.onCompleted: root.anim = Math.max(0, Math.min(1, root.value))

    implicitWidth: root.dim
    implicitHeight: root.dim + 15 * root.s

    Item {
        id: ringBox
        width: root.dim
        height: root.dim
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Theme.threadBg
                strokeWidth: 5 * root.s
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: root.dim / 2
                    centerY: root.dim / 2
                    radiusX: root.dim / 2 - 5 * root.s
                    radiusY: root.dim / 2 - 5 * root.s
                    startAngle: 135
                    sweepAngle: 270
                }
            }
            ShapePath {
                strokeColor: root.ringColor
                strokeWidth: 5 * root.s
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: root.dim / 2
                    centerY: root.dim / 2
                    radiusX: root.dim / 2 - 5 * root.s
                    radiusY: root.dim / 2 - 5 * root.s
                    startAngle: 135
                    sweepAngle: 270 * root.anim
                }
            }
        }
        Text {
            anchors.centerIn: parent
            text: root.readout
            color: Theme.inkOn(Theme.effectiveSurface, Theme.onSurface)
            font.family: Theme.mono
            font.pixelSize: 12.5 * root.s
            font.weight: Font.DemiBold
        }
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        text: root.label
        color: Theme.onSurfaceVariant
        font.family: Theme.fontPrimary
        font.pixelSize: 8.5 * root.s
        font.weight: Font.DemiBold
        font.letterSpacing: 1.2 * root.s
    }
}
