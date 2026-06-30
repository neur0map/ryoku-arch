import QtQuick
import QtQuick.Shapes

// Stroked vector icons from SVG path data, the same renderer Ryoku Settings and
// ryowalls use, so glyphs match across the family. tint-able, scalable, no assets.
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
        "search": "M10.5 4a6.5 6.5 0 0 1 0 13a6.5 6.5 0 0 1 0 -13z M15.4 15.4L20 20",
        "gear": "M12 8.5a3.5 3.5 0 0 1 0 7a3.5 3.5 0 0 1 0 -7z M12 2.5l1.4 2.2 2.6-.5.4 2.6 2.3 1.3-1.1 2.4 1.1 2.4-2.3 1.3-.4 2.6-2.6-.5L12 21.5l-1.4-2.2-2.6.5-.4-2.6-2.3-1.3 1.1-2.4-1.1-2.4 2.3-1.3.4-2.6 2.6.5z",
        "close": "M6 6l12 12M18 6L6 18",
        "download": "M21 15v4a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2v-4 M7 10l5 5 5-5 M12 15V3",
        "check": "M5 12.5l4.2 4.2L19 7",
        "refresh": "M21 12a9 9 0 1 1 -2.6 -6.4 M21 3v5h-5",
        "plus": "M12 5v14 M5 12h14",
        "folder": "M3 6a1 1 0 0 1 1 -1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1z",
        "display": "M3 5h18a1 1 0 0 1 1 1v9a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M9 20h6 M12 17v3",
        "chevron-left": "M15 6l-6 6 6 6",
        "chevron-right": "M9 6l6 6 -6 6",
        "external": "M14 4h6v6 M20 4l-9 9 M19 14v5a1 1 0 0 1 -1 1H5a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1h5",
        "terminal": "M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M7 9.5l3 2.5 -3 2.5 M12.5 15h4.5",
        "play": "M8 5.5l11 6.5 -11 6.5z",
        "stop": "M7 7h10v10H7z",
        "trash": "M5 7h14 M9 7V5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v2 M7 7l1 13a1 1 0 0 0 1 1h6a1 1 0 0 0 1 -1l1 -13 M10 11v6 M14 11v6",
        "camera": "M3 8a2 2 0 0 1 2 -2h2l1.5 -2h7L19 6h2a2 2 0 0 1 2 2v10a2 2 0 0 1 -2 2H3a2 2 0 0 1 -2 -2z M12 10.5a3 3 0 1 0 0 6a3 3 0 0 0 0 -6z",
        "snapshot": "M12 8a4 4 0 1 0 0 8a4 4 0 0 0 0 -8z M3 12a9 9 0 0 1 9 -9 M21 12a9 9 0 0 1 -9 9 M3 9v3h3 M21 15v-3h-3",
        "cpu": "M7 7h10v10H7z M10 10h4v4h-4z M9 3v2 M15 3v2 M9 19v2 M15 19v2 M3 9h2 M3 15h2 M19 9h2 M19 15h2",
        "memory": "M4 7h16a1 1 0 0 1 1 1v6a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1V8a1 1 0 0 1 1 -1z M7 15v3 M12 15v3 M17 15v3 M8 10v2 M12 10v2 M16 10v2",
        "disk": "M5 4h11l3 3v13a1 1 0 0 1 -1 1H5a1 1 0 0 1 -1 -1V5a1 1 0 0 1 1 -1z M8 4v5h7V4 M8 14h8v5H8z",
        "server": "M4 5h16a1 1 0 0 1 1 1v3a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M4 14h16a1 1 0 0 1 1 1v3a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1v-3a1 1 0 0 1 1 -1z M7 7.5h.01 M7 16.5h.01",
        "bolt": "M13 3L5 13h6l-1 8 8-10h-6z",
        "link": "M9 15l6 -6 M10.5 7.5l1.8 -1.8a3.5 3.5 0 0 1 5 5L15.5 12.5 M13.5 16.5l-1.8 1.8a3.5 3.5 0 0 1 -5 -5L8.5 11.5",
        "android": "M6 9a6 6 0 0 1 12 0v8H6z M6 13H4 M20 13h-2 M9 4l-1.5 -2 M15 4l1.5 -2 M9.5 7.5h.01 M14.5 7.5h.01 M9 21v-2 M15 21v-2",
        "window": "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M3 9h18 M6 7h.01"
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
            fillColor: icon.name === "play" || icon.name === "stop" ? icon.tint : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: icon.d }
        }
    }
}
