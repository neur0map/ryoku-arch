import QtQuick
import QtQuick.Shapes

// Stroked vector icons rendered from SVG path data, the same approach ryoshot
// uses: scalable, themeable by `tint`, and free of any shipped image asset.
Item {
    id: icon

    property string name: ""
    property color tint: "#e6d6cb"
    property real size: 20
    property real weight: 1.7

    implicitWidth: size
    implicitHeight: size

    readonly property real vb: 24

    readonly property var defs: ({
        "keyboard": "M2.5 7h19a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1h-19a1 1 0 0 1 -1 -1v-8a1 1 0 0 1 1 -1z M6 11h1 M9.5 11h1 M13 11h1 M16.5 11h1 M7.5 14.2h9",
        "sparkles": "M11 3.5l1.7 4.6L17.5 10l-4.8 1.9L11 16.5l-1.7-4.6L4.5 10l4.8-1.9z M18 14l.8 2.1 2.2.9-2.2.9-.8 2.1-.8-2.1-2.2-.9 2.2-.9z",
        "gear": "M12 8.5a3.5 3.5 0 0 1 0 7a3.5 3.5 0 0 1 0 -7z M12 2.5l1.4 2.2 2.6-.5.4 2.6 2.3 1.3-1.1 2.4 1.1 2.4-2.3 1.3-.4 2.6-2.6-.5L12 21.5l-1.4-2.2-2.6.5-.4-2.6-2.3-1.3 1.1-2.4-1.1-2.4 2.3-1.3.4-2.6 2.6.5z",
        "close": "M6 6l12 12M18 6L6 18",
        "search": "M10.5 4a6.5 6.5 0 0 1 0 13a6.5 6.5 0 0 1 0 -13z M15.4 15.4L20 20",
        "wrench": "M21 4a5 5 0 0 1 -6.5 6.5L5 20l-1-1 9.5-9.5A5 5 0 0 1 20 3z"
    })

    readonly property string d: defs[name] !== undefined ? defs[name] : ""

    Shape {
        anchors.centerIn: parent
        width: icon.vb
        height: icon.vb
        scale: icon.size / icon.vb
        preferredRendererType: Shape.CurveRenderer
        antialiasing: true

        ShapePath {
            strokeColor: icon.tint
            strokeWidth: icon.weight
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.d }
        }
    }
}
