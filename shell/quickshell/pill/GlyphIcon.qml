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
        "mixer": { d: "M6 4v16M12 4v16M18 4v16M3.5 9h5M9.5 15h5M15.5 7h5", fill: false },
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
        "hotspot": { d: "M12 12a1.3 1.3 0 1 0 0.01 0 M8.8 8.5A5 5 0 0 0 8.8 15.5 M15.2 8.5A5 5 0 0 1 15.2 15.5 M6 6A9 9 0 0 0 6 18 M18 6A9 9 0 0 1 18 18", fill: false }
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
