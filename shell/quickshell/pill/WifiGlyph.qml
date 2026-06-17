import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * Hand-drawn wifi glyph: three concentric arcs over a base dot, the lit-arc
 * count standing in for signal strength (>0.66 lights all three, >0.33 two,
 * >0 one). Lit strokes use iconDim, unlit use threadBg. When `!on` the arcs go
 * faint and a diagonal slash crosses the glyph. Paths sit centred in a 24x24
 * space scaled to the item; every weight scales by `s`.
 */
Item {
    id: root

    property real s: 1
    property real level: 0
    property bool on: true

    implicitWidth: 17 * s
    implicitHeight: 17 * s

    readonly property int litCount: !on ? 0 : (level > 0.66 ? 3 : (level > 0.33 ? 2 : (level > 0 ? 1 : 0)))
    readonly property color offColor: on ? Theme.threadBg : Qt.alpha(Theme.threadBg, 0.45)

    Shape {
        id: arcs
        anchors.fill: parent
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        readonly property real u: Math.min(width, height) / 24

        ShapePath {
            strokeColor: root.litCount >= 1 ? Theme.iconDim : root.offColor
            fillColor: "transparent"
            strokeWidth: 2 * root.s
            capStyle: ShapePath.RoundCap
            scale: Qt.size(arcs.u, arcs.u)
            PathSvg { path: "M9.17 13.17 A4 4 0 0 1 14.83 13.17" }
        }
        ShapePath {
            strokeColor: root.litCount >= 2 ? Theme.iconDim : root.offColor
            fillColor: "transparent"
            strokeWidth: 2 * root.s
            capStyle: ShapePath.RoundCap
            scale: Qt.size(arcs.u, arcs.u)
            PathSvg { path: "M6.34 10.34 A8 8 0 0 1 17.66 10.34" }
        }
        ShapePath {
            strokeColor: root.litCount >= 3 ? Theme.iconDim : root.offColor
            fillColor: "transparent"
            strokeWidth: 2 * root.s
            capStyle: ShapePath.RoundCap
            scale: Qt.size(arcs.u, arcs.u)
            PathSvg { path: "M3.5 7.5 A12 12 0 0 1 20.5 7.5" }
        }
        ShapePath {
            strokeColor: "transparent"
            fillColor: root.litCount >= 1 ? Theme.iconDim : root.offColor
            scale: Qt.size(arcs.u, arcs.u)
            PathSvg { path: "M12 14.1 A1.5 1.5 0 0 1 12 17.1 A1.5 1.5 0 0 1 12 14.1z" }
        }
        ShapePath {
            strokeColor: root.on ? "transparent" : Theme.faint
            fillColor: "transparent"
            strokeWidth: 1.8 * root.s
            capStyle: ShapePath.RoundCap
            scale: Qt.size(arcs.u, arcs.u)
            PathSvg { path: "M4 3 L20 19" }
        }
    }
}
