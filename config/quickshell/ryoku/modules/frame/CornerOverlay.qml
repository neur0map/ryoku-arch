import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

// Spec 2 follow-up: Paint solid black quarter-circles at the four
// screen corners on the overlay layer to simulate rounded physical
// display corners (a la modern phones / laptops with rounded screens).
// The black "fills" the corner area; a rounded cutout in the middle
// passes the rest of the screen through visually.
//
// Input is masked off entirely so clicks pass through to whatever
// window is below.
PanelWindow {
    id: root

    required property ShellScreen modelData
    screen: modelData

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.exclusionMode: ExclusionMode.Ignore
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    color: "transparent"
    surfaceFormat.opaque: false

    anchors {
        top: true
        left: true
        right: true
        bottom: true
    }

    // Empty input mask so all clicks pass through to windows below.
    mask: Region {}

    // Tunable: matches Config.rounding so the corner radius is
    // consistent with other rounded chrome on screen.
    property int cornerRadius: Config.rounding

    Shape {
        anchors.fill: parent
        asynchronous: false

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: "black"
            fillRule: ShapePath.OddEvenFill

            // Outer: full monitor rectangle (clockwise).
            startX: 0
            startY: 0
            PathLine { x: root.width; y: 0 }
            PathLine { x: root.width; y: root.height }
            PathLine { x: 0; y: root.height }
            PathLine { x: 0; y: 0 }

            // Inner cutout: the visible area, rounded rectangle the
            // exact size of the monitor minus rounded corners.
            PathMove { x: root.cornerRadius; y: 0 }
            PathLine { x: root.width - root.cornerRadius; y: 0 }
            PathArc {
                x: root.width
                y: root.cornerRadius
                radiusX: root.cornerRadius
                radiusY: root.cornerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.width; y: root.height - root.cornerRadius }
            PathArc {
                x: root.width - root.cornerRadius
                y: root.height
                radiusX: root.cornerRadius
                radiusY: root.cornerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: root.cornerRadius; y: root.height }
            PathArc {
                x: 0
                y: root.height - root.cornerRadius
                radiusX: root.cornerRadius
                radiusY: root.cornerRadius
                direction: PathArc.Clockwise
            }
            PathLine { x: 0; y: root.cornerRadius }
            PathArc {
                x: root.cornerRadius
                y: 0
                radiusX: root.cornerRadius
                radiusY: root.cornerRadius
                direction: PathArc.Clockwise
            }
        }
    }
}
