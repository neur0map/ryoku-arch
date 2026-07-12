import QtQuick
import QtQuick.Shapes

// Stroked vector icons from SVG path data, the same renderer Ryoku Settings and
// ryowalls use, so glyphs match the rest of the desktop. Tint-able, scalable,
// no asset files. One `name` -> one path in `defs`.
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
        "canvas": "M6 2v15a1 1 0 0 0 1 1h15 M2 6h15a1 1 0 0 1 1 1v15",
        "frame": "M3 3h18v18H3z M7 7h10v10H7z",
        "zoom": "M10.5 4a6.5 6.5 0 0 1 0 13a6.5 6.5 0 0 1 0 -13z M15.4 15.4L20 20 M10.5 7.5v6 M7.5 10.5h6",
        "cut": "M6 5a2 2 0 1 0 0 4a2 2 0 0 0 0 -4z M6 15a2 2 0 1 0 0 4a2 2 0 0 0 0 -4z M20 5L9 16 M20 19L9 8",
        "speed": "M4.5 17a9 9 0 1 1 15 0 M12 13l4-3.5",
        "text": "M5.5 7V5.5h13V7 M12 5.5v13 M9 18.5h6",
        "music": "M9 18a2.5 2.5 0 1 0 0 .01 M18 16a2.5 2.5 0 1 0 0 .01 M9 18V6l9-2v12",
        "cursor": "M5 3l14 7-6.5 1.7L11 19z",
        "export": "M12 3v12 M8 7l4-4 4 4 M4 14v5a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2v-5",
        "play": "M8 6l10 6-10 6z",
        "pause": "M9 5v14 M15 5v14",
        "record": "M12 6a6 6 0 1 0 0 12a6 6 0 0 0 0 -12z",
        "stop": "M6 6h12v12H6z",
        "plus": "M12 5v14 M5 12h14",
        "minus": "M5 12h14",
        "trash": "M3 6h18 M8 6V4a1 1 0 0 1 1 -1h6a1 1 0 0 1 1 1v2 M19 6l-1 14a1 1 0 0 1 -1 1H7a1 1 0 0 1 -1 -1L5 6 M10 11v6 M14 11v6",
        "folder": "M3 6a1 1 0 0 1 1 -1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1z",
        "film": "M4 4h16v16H4z M4 9h16 M4 15h16 M8.5 4v16 M15.5 4v16",
        "chevron-left": "M15 6l-6 6 6 6",
        "chevron-right": "M9 6l6 6 -6 6",
        "close": "M6 6l12 12M18 6L6 18",
        "check": "M5 12.5l4.2 4.2L19 7",
        "image": "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M8 11a1.5 1.5 0 1 0 0 .01 M21 16l-5-5-7 7",
        "wand": "M6 21l11-11 M14 7l3 3 M17 3l.6 1.9L19.5 5.5l-1.9.6L17 8l-.6-1.9L14.5 5.5l1.9-.6z"
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
