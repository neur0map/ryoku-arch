import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

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

    // Opaque frame of thickness Config.frameThickness on three edges
    // (left, right, bottom); the top edge is covered by Waybar so the
    // cutout reaches y = Config.waybarHeight. Windows are held further
    // inside the cutout by Hyprland gaps_out, which produces the
    // visible wallpaper matboard between frame and window.
    //
    // Mirrors Caelestia's BlobInvertedRect (plugin/src/Caelestia/Blobs/...)
    // which exposes per-edge borderLeft/borderRight/borderTop/borderBottom
    // thicknesses decoupled from window exclusion math.
    Shape {
        anchors.fill: parent
        asynchronous: false

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: Config.frameColor
            fillRule: ShapePath.OddEvenFill

            // Outer path: the full monitor, clockwise.
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            // Inner path: rounded-rect cutout, clockwise, all four corners
            // rounded with Config.rounding. Bounds at frameThickness on
            // left/right/bottom and waybarHeight on top.
            PathMove { x: Config.frameThickness + Config.rounding; y: Config.waybarHeight }
            PathLine { x: root.width - Config.frameThickness - Config.rounding; y: Config.waybarHeight }
            PathArc {
                x: root.width - Config.frameThickness
                y: Config.waybarHeight + Config.rounding
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Clockwise
            }
            PathLine { x: root.width - Config.frameThickness; y: root.height - Config.frameThickness - Config.rounding }
            PathArc {
                x: root.width - Config.frameThickness - Config.rounding
                y: root.height - Config.frameThickness
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Clockwise
            }
            PathLine { x: Config.frameThickness + Config.rounding; y: root.height - Config.frameThickness }
            PathArc {
                x: Config.frameThickness
                y: root.height - Config.frameThickness - Config.rounding
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Clockwise
            }
            PathLine { x: Config.frameThickness; y: Config.waybarHeight + Config.rounding }
            PathArc {
                x: Config.frameThickness + Config.rounding
                y: Config.waybarHeight
                radiusX: Config.rounding
                radiusY: Config.rounding
                direction: PathArc.Clockwise
            }
        }
    }
}
