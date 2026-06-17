import QtQuick
import QtQuick.Shapes

Item {
    id: icon

    property string name: ""
    property color tint: "#c4ccda"
    property real size: 18

    readonly property real vb: 24

    readonly property var defs: ({
        "select":  "M4 3l7 17 2-7 7-2z",
        "rect":    "M5 6h14a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1H5a1 1 0 0 1 -1 -1V7a1 1 0 0 1 1 -1z",
        "ellipse": "M20 12a8 6 0 0 1 -16 0a8 6 0 0 1 16 0z",
        "line":    "M5 19L19 5",
        "arrow":   "M5 19L19 5M19 5h-7M19 5v7",
        "pen":     "M4 18c3-1 4-6 8-9s6-4 8-5c-1 2-2 5-5 8s-8 5-9 8z",
        "text":    "M5 6h14M12 6v13",
        "marker":  "M4 15l10-10 4 4-10 10H4z",
        "blur":    "M11 9a2 2 0 0 1 -4 0a2 2 0 0 1 4 0z M17 13a2 2 0 0 1 -4 0a2 2 0 0 1 4 0z M10.5 16a1.5 1.5 0 0 1 -3 0a1.5 1.5 0 0 1 3 0z",
        "undo":    "M9 7L4 12l5 5M4 12h11a5 5 0 0 1 0 10",
        "redo":    "M15 7l5 5-5 5M20 12H9a5 5 0 0 0 0 10",
        "copy":    "M11 9h9a2 2 0 0 1 2 2v9a2 2 0 0 1 -2 2h-9a2 2 0 0 1 -2 -2v-9a2 2 0 0 1 2 -2z M5 15V5a2 2 0 0 1 2 -2h10",
        "save":    "M5 3h12l4 4v14H5zM8 3v6h8M8 21v-7h8v7",
        "upload":  "M12 16V4M7 9l5-5 5 5M5 20h14",
        "cancel":  "M6 6l12 12M18 6L6 18",
        "gear":    "M12 8.5a3.5 3.5 0 0 1 0 7a3.5 3.5 0 0 1 0 -7z M12 2.5l1.4 2.2 2.6-.5.4 2.6 2.3 1.3-1.1 2.4 1.1 2.4-2.3 1.3-.4 2.6-2.6-.5L12 21.5l-1.4-2.2-2.6.5-.4-2.6-2.3-1.3 1.1-2.4-1.1-2.4 2.3-1.3.4-2.6 2.6.5z"
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
            strokeWidth: 1.7
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.d }
        }
    }
}
