import QtQuick
import QtQuick.Shapes
import "Singletons"

// A small indeterminate spinner: a vermilion arc that sweeps continuously while
// an async provider (packages, find, music, calc) has a query in flight. The
// rotation runs on the render thread via RotationAnimator, so it stays smooth
// even when the UI thread is busy parsing results.
Item {
    id: root

    property real size: 16
    property color color: Theme.verm
    property real thickness: 2

    implicitWidth: size
    implicitHeight: size

    Shape {
        id: arc
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transformOrigin: Item.Center

        ShapePath {
            strokeColor: root.color
            strokeWidth: root.thickness
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: root.size / 2
            startY: root.thickness / 2
            PathAngleArc {
                centerX: root.size / 2
                centerY: root.size / 2
                radiusX: (root.size - root.thickness) / 2
                radiusY: (root.size - root.thickness) / 2
                startAngle: -90
                sweepAngle: 280
            }
        }

        RotationAnimator {
            target: arc
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
            running: root.visible
        }
    }
}
