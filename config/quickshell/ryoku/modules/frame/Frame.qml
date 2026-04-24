import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import ryoku.config

PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.exclusionMode: ExclusionMode.Ignore

    color: "transparent"
    surfaceFormat.opaque: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    Shape {
        anchors.fill: parent
        asynchronous: false
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Config.frameColor
            fillRule: ShapePath.OddEvenFill

            // Outer rectangle (the full monitor), clockwise
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            // Inner cutout: rounded-rect with no rounding on the top corners
            // (top edge has no drawn frame; the cutout reaches pixel 0 on top).
            PathMove { x: Config.sideExclusion; y: 0 }
            PathLine { x: Config.sideExclusion; y: root.height - Config.sideExclusion - Config.rounding }
            PathArc {
                x: Config.sideExclusion + Config.rounding
                y: root.height - Config.sideExclusion
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width - Config.sideExclusion - Config.rounding; y: root.height - Config.sideExclusion }
            PathArc {
                x: root.width - Config.sideExclusion
                y: root.height - Config.sideExclusion - Config.rounding
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Counterclockwise
            }
            PathLine { x: root.width - Config.sideExclusion; y: 0 }
            PathLine { x: Config.sideExclusion; y: 0 }
        }
    }
}
