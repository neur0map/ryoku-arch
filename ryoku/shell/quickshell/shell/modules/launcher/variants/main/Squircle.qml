import QtQuick
import QtQuick.Shapes

// A superellipse-rounded rectangle matching Hyprland's window rounding
// (rounding_power = 4), so the palette's corners read as the same shape as every
// tiled window instead of a plain circular radius. Drawn on the GPU via Shape +
// CurveRenderer. `radius` is a fixed pixel value, not content-scaled, because
// Hyprland rounds at a fixed radius regardless of window size.
//
// Content goes inside as ordinary children; they paint over the fill.
Item {
    id: root

    property real radius: 16   // launcher's outer window-matching shape stays round (Hyprland rounding); inner content is sharp
    property real power: 4
    property color color: "transparent"
    property color borderColor: "transparent"
    property real borderWidth: 0

    // Perimeter points, clockwise from the top-left corner. Each corner is a
    // quarter superellipse |x/r|^power + |y/r|^power = 1; straight edges fall out
    // of the polyline connecting adjacent corner ends. Args are read so the
    // binding re-runs on resize.
    function outline(w, h, r, p) {
        var rad = Math.min(r, Math.min(w, h) / 2);
        var k = 2 / p;
        var pts = [];
        function corner(cx, cy, a0, a1) {
            var steps = 10;
            for (var i = 0; i <= steps; i++) {
                var t = (a0 + (a1 - a0) * i / steps) * Math.PI / 180;
                var ct = Math.cos(t), st = Math.sin(t);
                var x = cx + rad * Math.sign(ct) * Math.pow(Math.abs(ct), k);
                var y = cy + rad * Math.sign(st) * Math.pow(Math.abs(st), k);
                pts.push(Qt.point(x, y));
            }
        }
        corner(rad, rad, 180, 270);             // top-left
        corner(w - rad, rad, 270, 360);         // top-right
        corner(w - rad, h - rad, 0, 90);        // bottom-right
        corner(rad, h - rad, 90, 180);          // bottom-left
        pts.push(pts[0]);                        // close
        return pts;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: root.color
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth
            joinStyle: ShapePath.RoundJoin
            PathPolyline {
                path: root.outline(root.width, root.height, root.radius, root.power)
            }
        }
    }
}
