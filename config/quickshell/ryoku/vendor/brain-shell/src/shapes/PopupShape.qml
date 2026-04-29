import QtQuick
import QtQuick.Shapes
import "../"

// Draws a popup background that "melts" into whichever edge it's
// attached to. GPU-accelerated via QtQuick.Shapes (Shape + ShapePath
// + PathSvg) so animated resize stays smooth at high refresh rates.
// The previous Canvas implementation re-rasterized on the CPU on every
// width/height change, which dropped the dashboard expansion to ~20 FPS
// on a 165 Hz panel.
Item {
    id: root

    property string attachedEdge: "top"
    property color  color:        Theme.background
    property color  strokeColor:  "transparent"
    property real   strokeWidth:  0

    property int radius:      Theme.cornerRadius
    property int flareWidth:  Theme.cornerRadius
    property int flareHeight: Theme.cornerRadius

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        asynchronous: false

        ShapePath {
            fillColor:   root.color
            strokeColor: root.strokeColor
            strokeWidth: root.strokeWidth
            joinStyle:   ShapePath.RoundJoin
            capStyle:    ShapePath.RoundCap

            PathSvg {
                path: root._buildPath(root.width, root.height, root.radius,
                                      root.flareWidth, root.flareHeight,
                                      root.attachedEdge)
            }
        }
    }

    // SVG arc form: "A rx ry x-rotation large-arc-flag sweep-flag x y".
    // sweep-flag is chosen per edge so corners curve into the body
    // rather than away from it.
    function _buildPath(w, h, r, fw, fh, edge) {
        switch (edge) {
        case "top":
            return "M 0 0"
                + " Q " + fw + " 0 " + fw + " " + fh
                + " L " + fw + " " + (h - r)
                + " A " + r + " " + r + " 0 0 0 " + (fw + r) + " " + h
                + " L " + (w - fw - r) + " " + h
                + " A " + r + " " + r + " 0 0 0 " + (w - fw) + " " + (h - r)
                + " L " + (w - fw) + " " + fh
                + " Q " + (w - fw) + " 0 " + w + " 0 Z"

        case "left":
            return "M 0 0"
                + " Q 0 " + fh + " " + fw + " " + fh
                + " L " + (w - r) + " " + fh
                + " A " + r + " " + r + " 0 0 1 " + w + " " + (fh + r)
                + " L " + w + " " + (h - fh - r)
                + " A " + r + " " + r + " 0 0 1 " + (w - r) + " " + (h - fh)
                + " L " + fw + " " + (h - fh)
                + " Q 0 " + (h - fh) + " 0 " + h + " Z"

        case "right":
            return "M " + w + " 0"
                + " Q " + w + " " + fh + " " + (w - fw) + " " + fh
                + " L " + r + " " + fh
                + " A " + r + " " + r + " 0 0 0 0 " + (fh + r)
                + " L 0 " + (h - fh - r)
                + " A " + r + " " + r + " 0 0 0 " + r + " " + (h - fh)
                + " L " + (w - fw) + " " + (h - fh)
                + " Q " + w + " " + (h - fh) + " " + w + " " + h + " Z"

        case "bottom":
            return "M 0 " + h
                + " Q " + fw + " " + h + " " + fw + " " + (h - fh)
                + " L " + fw + " " + r
                + " A " + r + " " + r + " 0 0 1 " + (fw + r) + " 0"
                + " L " + (w - fw - r) + " 0"
                + " A " + r + " " + r + " 0 0 1 " + (w - fw) + " " + r
                + " L " + (w - fw) + " " + (h - fh)
                + " Q " + (w - fw) + " " + h + " " + w + " " + h + " Z"
        }
        return ""
    }
}
