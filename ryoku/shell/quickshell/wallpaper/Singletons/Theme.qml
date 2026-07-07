pragma Singleton
import QtQuick
import Quickshell

// Wallpaper switcher palette + geometry, a focused twin of the shell Theme
// (docs/ui-ux.md tokens). Accent follows the wallpaper when Match wallpaper is
// on; the fixed fallback is the Ryoku brand vermillion. Brutalist geometry:
// radius 0, hairline borders.
Singleton {
    readonly property color brand:    Config.matchWallpaper ? Wallust.accent : "#e2342a"
    readonly property color vermLit:  Config.matchWallpaper ? Qt.lighter(Wallust.accent, 1.22) : "#e83b30"
    readonly property color vermDeep: Config.matchWallpaper ? Qt.darker(Wallust.accent, 1.3) : "#b81f19"

    // warm-white text ramp (website --ink).
    readonly property color bright:   "#f3ede1"
    readonly property color cream:    "#e6dccb"
    readonly property color subtle:   "#c7bfae"
    readonly property color dim:      "#8f8770"
    readonly property color faint:    "#5c5249"

    // near-black canvas (website --paper), or wallust surfaces when matching.
    readonly property color cardTop:  Config.matchWallpaper ? Wallust.base     : "#16110b"
    readonly property color cardBot:  Config.matchWallpaper ? Wallust.deep     : "#0f0c07"
    readonly property color tileBg:   Config.matchWallpaper ? Wallust.elevated : "#1b150e"
    readonly property color border:   Config.matchWallpaper ? Wallust.line     : Qt.rgba(243/255, 237/255, 225/255, 0.14)
    readonly property color hair:     Qt.rgba(243/255, 237/255, 225/255, 0.12)
    readonly property color sheen:    Qt.rgba(243/255, 237/255, 225/255, 0.06)

    // accent tints for selected fills / active chips.
    readonly property color frameBg:  Qt.rgba(226/255, 52/255, 42/255, 0.14)

    // type stack + brutalist geometry (website language).
    readonly property string font:    Config.fontFamily.length > 0 ? Config.fontFamily : "Space Grotesk"
    readonly property string display: "Fraunces"
    readonly property string fontJp:  "Noto Sans CJK JP"
    readonly property string mono:    "JetBrainsMono Nerd Font"
    readonly property int    radius:  0
}
