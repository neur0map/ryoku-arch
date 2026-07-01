import QtQuick
import QtQuick.Shapes
import "Singletons"

// Six-glyph weather icon for the launcher. Path data is copied verbatim from the
// pill's GlyphIcon so the two shells render the same weather mark; we ship only
// the six names Weather.glyph can actually emit (sun cloud rain snow fog storm)
// because the launcher never draws any other vector icon and hauling in the full
// GlyphIcon catalog would be dead weight. Stroked, 24x24 base box, scaled to fit
// via the same u factor as GlyphIcon.
Item {
    id: root

    property string name: ""
    property color color: Theme.iconDim
    property real stroke: 1.8

    readonly property real u: Math.min(width, height) / 24

    // path data lifted verbatim from pill/GlyphIcon.qml so the two shells agree.
    readonly property var glyphs: ({
        "sun": "M16 12a4 4 0 1 0-8 0a4 4 0 1 0 8 0 M12 2v2 M12 20v2 M4.2 4.2l1.4 1.4 M18.4 18.4l1.4 1.4 M2 12h2 M20 12h2 M4.2 19.8l1.4-1.4 M18.4 5.6l1.4-1.4",
        "cloud": "M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z",
        "rain":  "M16 13v6 M8 13v6 M12 15v6 M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25",
        "snow":  "M20 17.58A5 5 0 0 0 18 8h-1.26A8 8 0 1 0 4 16.25 M8 16h.01 M8 20h.01 M12 18h.01 M12 22h.01 M16 16h.01 M16 20h.01",
        "fog":   "M4 9h16 M4 13h16 M7 17h10",
        "storm": "M19 16.9A5 5 0 0 0 18 7h-1.26a8 8 0 1 0-11.62 9 M13 11l-4 6h6l-4 6"
    })

    readonly property string d: glyphs[name] !== undefined ? glyphs[name] : ""

    Shape {
        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.color
            fillColor: "transparent"
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.d }
        }
    }
}
