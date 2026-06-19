import QtQuick
import QtQuick.Shapes
import "Singletons"

/**
 * Self-contained vector glyph drawn from baked SVG path data, so the pill never
 * depends on the system icon theme or external asset files. Set `name` to pick a
 * glyph, `color` to tint it; stroked glyphs use `stroke` width, filled glyphs
 * (media transport) paint solid. Paths live in a 24x24 space and scale to the
 * item's size.
 */
Item {
    id: root

    property string name: ""
    property color color: Theme.iconDim
    property real stroke: 1.8
    property real fillProgress: 1

    readonly property real u: Math.min(width, height) / 24

    readonly property var glyphs: ({
        "sun": { d: "M16 12a4 4 0 1 0-8 0a4 4 0 1 0 8 0 M12 2v2 M12 20v2 M4.2 4.2l1.4 1.4 M18.4 18.4l1.4 1.4 M2 12h2 M20 12h2 M4.2 19.8l1.4-1.4 M18.4 5.6l1.4-1.4", fill: false },
        "monitor": { d: "M4 4h16a2 2 0 0 1 2 2v9a2 2 0 0 1-2 2h-16a2 2 0 0 1-2-2v-9a2 2 0 0 1 2-2z M8 21h8 M12 17v4 M7 13c1.5-4 3-4 5-1s3.5 2 5-2", fill: false },
        "speaker": { d: "M4 9v6h4l5 4V5L8 9z M16 9.5a3 3 0 0 1 0 5 M18.5 7.5a6 6 0 0 1 0 9", fill: false },
        "speaker-off": { d: "M4 9v6h4l5 4V5L8 9z M16.2 9.8l4.4 4.4 M20.6 9.8l-4.4 4.4", fill: false },
        "mic": { d: "M9 9V6a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0 M5 11a7 7 0 0 0 14 0 M12 18v3", fill: false },
        "mic-off": { d: "M9 9V6a3 3 0 0 1 6 0v3 M15 12v0a3 3 0 0 1-5.6 1.5 M5 11a7 7 0 0 0 11 5.5 M12 19v3 M3 3l18 18", fill: false },
        "lock": { d: "M6 10h12a1.5 1.5 0 0 1 1.5 1.5v6a1.5 1.5 0 0 1-1.5 1.5H6a1.5 1.5 0 0 1-1.5-1.5v-6A1.5 1.5 0 0 1 6 10z M8.5 10V7a3.5 3.5 0 0 1 7 0v3", fill: false },
        "lock-round": { d: "M8 8.5H16A3 3 0 0 1 19 11.5V15.5A3 3 0 0 1 16 18.5H8A3 3 0 0 1 5 15.5V11.5A3 3 0 0 1 8 8.5Z M8.4 8.5V5.7A3.6 3.6 0 0 1 15.6 5.7V8.5", fill: false },
        "logout": { d: "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4 M16 17l5-5-5-5 M21 12H9", fill: false },
        "suspend": { d: "M21 12.8A9 9 0 1 1 11.2 3 7 7 0 0 0 21 12.8z", fill: false },
        "reboot": { d: "M21 12a9 9 0 1 1-2.6-6.4 M21 3v5h-5", fill: false },
        "shutdown": { d: "M12 3v9 M7.8 6.3a8 8 0 1 0 8.4 0", fill: false },
        "music": { d: "M9 18V5l12-2v13 M9 18a3 3 0 1 1-6 0 3 3 0 0 1 6 0z M21 16a3 3 0 1 1-6 0 3 3 0 0 1 6 0z", fill: false },
        "play": { d: "M7 5l12 7-12 7z", fill: true },
        "pause": { d: "M8 5h3v14H8z M13 5h3v14h-3z", fill: true },
        "next": { d: "M6 5l9 7-9 7z M16 5h2v14h-2z", fill: true },
        "prev": { d: "M18 5l-9 7 9 7z M6 5h2v14H6z", fill: true },
        "play-s": { d: "M8 5.5l10.5 6.5L8 18.5z", fill: false },
        "pause-s": { d: "M9 5.5v13 M15 5.5v13", fill: false },
        "next-s": { d: "M7 5.5l9 6.5-9 6.5z M17 5.5v13", fill: false },
        "prev-s": { d: "M17 5.5l-9 6.5 9 6.5z M7 5.5v13", fill: false },
        "dnd": { d: "M6 16V11a6 6 0 0 1 9.3-5M18 11v5M4 16h16M10.5 20a1.8 1.8 0 0 0 3 0M3 3l18 18", fill: false },
        "awake": { d: "M2 12s3.5-6 10-6 10 6 10 6-3.5 6-10 6-10-6-10-6zM12 9a3 3 0 1 0 0 6 3 3 0 0 0 0-6z", fill: false },
        "chevron-left": { d: "M14 6l-6 6 6 6", fill: false },
        "chevron-right": { d: "M10 6l6 6-6 6", fill: false },
        "wifi": { d: "M4 9.5C9 4.8 15 4.8 20 9.5 M7 13c3-2.8 7-2.8 10 0 M11 16.8a1.4 1.4 0 1 0 2 0a1.4 1.4 0 1 0-2 0", fill: false },
        "ethernet": { d: "M5 5h14a1.5 1.5 0 0 1 1.5 1.5v8a1.5 1.5 0 0 1-1.5 1.5H5a1.5 1.5 0 0 1-1.5-1.5v-8A1.5 1.5 0 0 1 5 5z M8 19h8 M12 16v3 M8 8.5v3.5 M12 8.5v3.5 M16 8.5v3.5", fill: false },
        "bluetooth": { d: "M12 2.8v18.4 M12 2.8l5.2 4.6-10.4 9 M12 21.2l5.2-4.6-10.4-9", fill: false },
        "inbox": { d: "M6 16v-5a6 6 0 0 1 12 0v5 M4 16h16 M10.5 20a1.8 1.8 0 0 0 3 0", fill: false },
        "cpu": { d: "M5 4h14a1 1 0 0 1 1 1v14a1 1 0 0 1-1 1H5a1 1 0 0 1-1-1V5a1 1 0 0 1 1-1z M9 9h6v6H9z M9 2v2 M15 2v2 M9 20v2 M15 20v2 M20 9h2 M20 15h2 M2 9h2 M2 15h2", fill: false },
        "archive": { d: "M21 8v13H3V8 M1 3h22v5H1z M10 12h4", fill: false },
        "cloud": { d: "M18 10h-1.26A8 8 0 1 0 9 20h9a5 5 0 0 0 0-10z", fill: false },
        "rain": { d: "M16 13v6 M8 13v6 M12 15v6 M20 16.58A5 5 0 0 0 18 7h-1.26A8 8 0 1 0 4 15.25", fill: false },
        "snow": { d: "M20 17.58A5 5 0 0 0 18 8h-1.26A8 8 0 1 0 4 16.25 M8 16h.01 M8 20h.01 M12 18h.01 M12 22h.01 M16 16h.01 M16 20h.01", fill: false },
        "fog": { d: "M4 9h16 M4 13h16 M7 17h10", fill: false },
        "storm": { d: "M19 16.9A5 5 0 0 0 18 7h-1.26a8 8 0 1 0-11.62 9 M13 11l-4 6h6l-4 6", fill: false },
        "hotspot": { d: "M12 12a1.3 1.3 0 1 0 0.01 0 M8.8 8.5A5 5 0 0 0 8.8 15.5 M15.2 8.5A5 5 0 0 1 15.2 15.5 M6 6A9 9 0 0 0 6 18 M18 6A9 9 0 0 1 18 18", fill: false },
        "send": { d: "M22 2L11 13M22 2L15 22L11 13L2 9Z", fill: false },
        "install": { d: "M21 8v10a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8 M3 8l9-5 9 5 M9 11l3 3 3-3 M12 14V5", fill: false },
        "compress": { d: "M4 14h6v6 M20 10h-6V4 M14 10l7-7 M3 21l7-7", fill: false },
        "download": { d: "M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4 M7 10l5 5 5-5 M12 15V3", fill: false },
        "lens": { d: "M4 9V6.5A2.5 2.5 0 0 1 6.5 4H9 M15 4h2.5A2.5 2.5 0 0 1 20 6.5V9 M20 15v2.5A2.5 2.5 0 0 1 17.5 20H15 M9 20H6.5A2.5 2.5 0 0 1 4 17.5V15 M12 9.5a2.5 2.5 0 1 0 0 5 2.5 2.5 0 0 0 0-5z", fill: false },
        "ocr": { d: "M4 8V6a2 2 0 0 1 2-2h2 M16 4h2a2 2 0 0 1 2 2v2 M20 16v2a2 2 0 0 1-2 2h-2 M8 20H6a2 2 0 0 1-2-2v-2 M8 9.5h8 M8 12.5h8 M8 15.5h5", fill: false },
        "webcam": { d: "M12 3.5a7.5 7.5 0 1 0 0 15 7.5 7.5 0 0 0 0-15z M12 8a3 3 0 1 0 0 6 3 3 0 0 0 0-6z M8.5 21h7", fill: false },
        "eyedropper": { d: "M4 20l1-3.5 8.5-8.5 2.5 2.5-8.5 8.5L4 20z M14.5 6l3.5 3.5 1.5-1.5a1.8 1.8 0 0 0-3.5-3.5z", fill: false },
        "coffee": { d: "M5 10H14V14.5A3 3 0 0 1 11 17.5H8A3 3 0 0 1 5 14.5Z M14 11C20 11 20 15 14 15 M8.5 8C9.2 7.1 7.8 6.3 8.5 5.3 M11.5 8C12.2 7.1 10.8 6.3 11.5 5.3", fill: false },
        "record": { d: "M12 6.5a5.5 5.5 0 1 0 0 11 5.5 5.5 0 0 0 0-11z", fill: true },
        "stop": { d: "M8 7h8a1 1 0 0 1 1 1v8a1 1 0 0 1-1 1H8a1 1 0 0 1-1-1V8a1 1 0 0 1 1-1z", fill: true },
        "folder": { d: "M3 7.5A1.5 1.5 0 0 1 4.5 6h4l2 2h9A1.5 1.5 0 0 1 21 9.5v8A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5z", fill: false },
        "trash": { d: "M4 7h16 M9 7V5.2A1.2 1.2 0 0 1 10.2 4h3.6A1.2 1.2 0 0 1 15 5.2V7 M6.5 7l0.9 11.2A1.8 1.8 0 0 0 9.2 20h5.6a1.8 1.8 0 0 0 1.8-1.7L17.5 7 M10 11v5 M14 11v5", fill: false },
        "list": { d: "M8 6h12 M8 12h12 M8 18h12 M4 6h.01 M4 12h.01 M4 18h.01", fill: false },
        "region": { d: "M5 9V6.5A1.5 1.5 0 0 1 6.5 5H9 M15 5h2.5A1.5 1.5 0 0 1 19 6.5V9 M19 15v2.5A1.5 1.5 0 0 1 17.5 19H15 M9 19H6.5A1.5 1.5 0 0 1 5 17.5V15", fill: false },
        "chevron-down": { d: "M6 9l6 6 6-6", fill: false },
        "file": { d: "M13 3H7a1.6 1.6 0 0 0-1.6 1.6v14.8A1.6 1.6 0 0 0 7 21h10a1.6 1.6 0 0 0 1.6-1.6V8.6z M13 3v5.6h5.6", fill: false },
        "image": { d: "M4.5 5h15A1.5 1.5 0 0 1 21 6.5v11A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5v-11A1.5 1.5 0 0 1 4.5 5z M8 11a1.6 1.6 0 1 0 0-3.2 1.6 1.6 0 0 0 0 3.2z M21 15.5l-4.5-4.5L7 20.5", fill: false },
        "code": { d: "M9 8l-4 4 4 4 M15 8l4 4-4 4 M13 5l-2 14", fill: false },
        "film": { d: "M4.5 5h15A1.5 1.5 0 0 1 21 6.5v11A1.5 1.5 0 0 1 19.5 19h-15A1.5 1.5 0 0 1 3 17.5v-11A1.5 1.5 0 0 1 4.5 5z M8 5v14 M16 5v14 M3 9h5 M16 9h5 M3 15h5 M16 15h5", fill: false },
        "qr": { d: "M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h2.5v2.5h-2.5z M17.5 17.5h2.5v2.5h-2.5z M14 18h2v2h-2z M18 14h2v2h-2z", fill: true },
        "moon": { d: "M12 3a6.4 6.4 0 0 0 9 9 9 9 0 1 1-9-9z", fill: false }
    })

    readonly property var g: glyphs[name] !== undefined ? glyphs[name] : ({ d: "", fill: false })

    Shape {
        width: 24
        height: 24
        scale: root.u
        transformOrigin: Item.TopLeft
        antialiasing: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.g.fill ? "transparent" : root.color
            fillColor: root.g.fill ? root.color : "transparent"
            strokeWidth: root.stroke
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: root.g.d }
        }
    }
}
