import QtQuick
import QtQuick.Shapes

// Stroked vector icons from SVG path data, the same renderer Ryoku Settings
// uses, so glyphs match the hub exactly. `tint`-able, scalable, no asset files.
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
        "palette": "M12 3a9 9 0 1 0 0 18c1.1 0 1.8-.9 1.8-1.9 0-1.1-.9-1.6-.9-2.4 0-.8.7-1.4 1.5-1.4H17a4 4 0 0 0 4-4c0-4.5-4-8-9-8z M7.5 11a1 1 0 1 0 0 .01 M11 7.5a1 1 0 1 0 0 .01 M15.5 10a1 1 0 1 0 0 .01",
        "image": "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M8 11a1.5 1.5 0 1 0 0 .01 M21 16l-5-5-7 7",
        "wallpaper": "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M8 11a1.5 1.5 0 1 0 0 .01 M21 16l-5-5-7 7",
        "sparkles": "M11 3.5l1.7 4.6L17.5 10l-4.8 1.9L11 16.5l-1.7-4.6L4.5 10l4.8-1.9z M18 14l.8 2.1 2.2.9-2.2.9-.8 2.1-.8-2.1-2.2-.9 2.2-.9z",
        "star": "M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 17l-5.2 2.6 1-5.8-4.3-4.1 5.9-.9z",
        "plus": "M12 5v14 M5 12h14",
        "folder": "M3 6a1 1 0 0 1 1 -1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1z",
        "display": "M3 5h18a1 1 0 0 1 1 1v9a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M9 20h6 M12 17v3",
        "chevron-left": "M15 6l-6 6 6 6",
        "chevron-right": "M9 6l6 6 -6 6",
        "shuffle": "M3 7h3.5l9 10H21 M18.5 4L21 7l-2.5 3 M3 17h3.5l3-3.4 M14.5 8.6l1-1.1H21 M18.5 20L21 17l-2.5-3",
        "sliders": "M4 7h9 M17 7h3 M4 12h3 M11 12h9 M4 17h12 M20 17h0 M14.5 5.5v3 M8.5 10.5v3 M17.5 15.5v3",
        "external": "M14 4h6v6 M20 4l-9 9 M19 14v5a1 1 0 0 1 -1 1H5a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1h5",
        "terminal": "M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M7 9.5l3 2.5 -3 2.5 M12.5 15h4.5"
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
