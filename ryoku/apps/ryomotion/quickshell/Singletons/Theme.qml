pragma Singleton
import QtQuick
import Quickshell

// Ryoku Motion palette: the warm-dark Ryoku tokens (ember on ink), shared with
// the hub/ryowalls, but with friendly rounded radii -- this is a soft, approachable
// creative tool, so controls are pill-round rather than the brand's sharp edges.
Singleton {
    readonly property color brand:     "#e2342a"
    readonly property color ember:     "#e83b30"
    readonly property color emberDeep: "#b81f19"
    readonly property color gold:      "#f5b53f"

    readonly property color ok:        "#7fbf6a"
    readonly property color bad:       "#e05a5a"

    // window + surfaces (frosted warm dark)
    readonly property color bgTop:     "#1b1610"
    readonly property color bgBot:     "#100d09"
    readonly property color panel:     Qt.rgba(30 / 255, 25 / 255, 18 / 255, 0.92)
    readonly property color panelLo:   Qt.rgba(20 / 255, 17 / 255, 12 / 255, 0.86)
    readonly property color field:     Qt.rgba(1, 1, 1, 0.05)
    readonly property color fieldHi:   Qt.rgba(1, 1, 1, 0.09)
    readonly property color hair:      Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.12)
    readonly property color hairSoft:  Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.06)

    // text
    readonly property color bright:    "#f5efe4"
    readonly property color cream:     "#e6dccb"
    readonly property color idle:      "#c7bfae"
    readonly property color dim:       "#8f8378"
    readonly property color faint:     "#5c5249"

    readonly property string display:  "Fraunces"
    readonly property string font:     "Space Grotesk"
    readonly property string fontJp:   "Noto Sans CJK JP"
    readonly property string mono:     "JetBrainsMono Nerd Font"

    // friendly radii (borumi-soft)
    readonly property int radius:    14
    readonly property int radiusSm:  9
    readonly property int radiusLg:  20

    readonly property int quick:  120
    readonly property int medium: 220
    readonly property int slow:   360
    readonly property int ease:   Easing.OutCubic
}
