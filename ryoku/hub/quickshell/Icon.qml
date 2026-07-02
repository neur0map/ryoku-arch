import QtQuick
import QtQuick.Shapes

// stroked vector icons from SVG path data, ryoshot-style: scalable,
// `tint`-able, no shipped image asset.
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
        "wrench": "M21 4a5 5 0 0 1 -6.5 6.5L5 20l-1-1 9.5-9.5A5 5 0 0 1 20 3z",
        "download": "M21 15v4a2 2 0 0 1 -2 2H5a2 2 0 0 1 -2 -2v-4 M7 10l5 5 5-5 M12 15V3",
        "check": "M5 12.5l4.2 4.2L19 7",
        "refresh": "M21 12a9 9 0 1 1 -2.6 -6.4 M21 3v5h-5",
        "display": "M3 5h18a1 1 0 0 1 1 1v9a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M9 20h6 M12 17v3",
        "palette": "M12 3a9 9 0 1 0 0 18c1.1 0 1.8-.9 1.8-1.9 0-1.1-.9-1.6-.9-2.4 0-.8.7-1.4 1.5-1.4H17a4 4 0 0 0 4-4c0-4.5-4-8-9-8z M7.5 11a1 1 0 1 0 0 .01 M11 7.5a1 1 0 1 0 0 .01 M15.5 10a1 1 0 1 0 0 .01",
        "mouse": "M12 2.5a5.5 5.5 0 0 1 5.5 5.5v8a5.5 5.5 0 0 1 -11 0V8A5.5 5.5 0 0 1 12 2.5z M12 6.5v4",
        "plus": "M12 5v14 M5 12h14",
        "trash": "M4 7h16 M9 7V5a1 1 0 0 1 1 -1h4a1 1 0 0 1 1 1v2 M6.5 7l.9 12.1a1 1 0 0 0 1 .9h7.2a1 1 0 0 0 1 -.9L18.5 7 M10 11v5 M14 11v5",
        "terminal": "M4 5h16a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M7 9.5l3 2.5 -3 2.5 M12.5 15h4.5",
        "rocket": "M5 15c-1.5 1.5 -1.5 4 -1.5 4s2.5 0 4 -1.5 M9 11a8 8 0 0 1 8 -8c2 0 3 1 3 3a8 8 0 0 1 -8 8z M9 11l-3 1 5 5 1 -3 M14.5 8.5a1.2 1.2 0 1 0 0 .01",
        "variable": "M8 4c-2.4 3.2 -2.4 12.8 0 16 M16 4c2.4 3.2 2.4 12.8 0 16 M9.5 9l5 6 M14.5 9l-5 6",
        "chevron": "M6 9.5l6 6 6 -6",
        "expand": "M8 9l4 -4 4 4 M8 15l4 4 4 -4",
        "collapse": "M8 6l4 4 4 -4 M8 18l4 -4 4 4",
        "window": "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M3 9h18",
        "motion": "M4 18C8 18 8 6 12 6S16 18 20 18 M4 18a1.4 1.4 0 1 0 0 .01 M20 18a1.4 1.4 0 1 0 0 .01",
        "lock": "M5 11h14a1 1 0 0 1 1 1v8a1 1 0 0 1 -1 1H5a1 1 0 0 1 -1 -1v-8a1 1 0 0 1 1 -1z M8 11V7.5a4 4 0 0 1 8 0V11 M12 15v2.5",
        "play": "M8 5.4l11 6.6 -11 6.6z",
        "user": "M12 4.2a3.8 3.8 0 0 1 0 7.6a3.8 3.8 0 0 1 0 -7.6z M5 20a7 7 0 0 1 14 0",
        "wifi": "M4 9.5a11 11 0 0 1 16 0 M7.5 13a6 6 0 0 1 9 0 M10.5 16.3a2 2 0 0 1 3 0 M12 19.2h.01",
        "widgets": "M4 4h6v6h-6z M14 4h6v6h-6z M4 14h6v6h-6z M14 14h6v6h-6z",
        "verified": "M12 3l2.3 1.8 2.9-.2.6 2.8 2.4 1.6-1.2 2.6 1.2 2.6-2.4 1.6-.6 2.8-2.9-.2L12 21l-2.3-1.8-2.9.2-.6-2.8-2.4-1.6 1.2-2.6-1.2-2.6 2.4-1.6.6-2.8 2.9.2z M8.5 12l2.3 2.3 4.7-4.7",
        "users": "M9 5.2a3.3 3.3 0 0 1 0 6.6a3.3 3.3 0 0 1 0 -6.6z M3.5 20a5.5 5.5 0 0 1 11 0 M16 5.5a3.2 3.2 0 0 1 0 6 M17.5 14.5a5.5 5.5 0 0 1 3 5",
        "wallpaper": "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M8 11a1.5 1.5 0 1 0 0 .01 M21 16l-5-5-7 7",
        "image": "M3 5h18a1 1 0 0 1 1 1v12a1 1 0 0 1 -1 1H3a1 1 0 0 1 -1 -1V6a1 1 0 0 1 1 -1z M8 11a1.5 1.5 0 1 0 0 .01 M21 16l-5-5-7 7",
        "star": "M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 17l-5.2 2.6 1-5.8-4.3-4.1 5.9-.9z",
        "chip": "M7 7h10v10H7z M9 3v4 M12 3v4 M15 3v4 M9 17v4 M12 17v4 M15 17v4 M3 9h4 M3 12h4 M3 15h4 M17 9h4 M17 12h4 M17 15h4",
        "folder": "M3 6a1 1 0 0 1 1 -1h5l2 2h9a1 1 0 0 1 1 1v10a1 1 0 0 1 -1 1H4a1 1 0 0 1 -1 -1z",
        "compass": "M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0 -20z M14.8 9.2l-2 5.6l-5.6 2l2 -5.6z"
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
