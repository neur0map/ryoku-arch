pragma Singleton
import QtQuick
import Quickshell

// shared widget tokens. brand constant, type family, a small neutral ink
// ramp. widgets sit on the wallpaper so text leans bright/cool and colour
// accents come from Wallust; brand orange stays fixed (the one deliberate
// highlight). motion = the shell's morph curve (OutExpo), so a widget
// feels like the same desktop as the pill.
Singleton {
    // brand: fixed, used sparingly. the one accent that never themes.
    readonly property color brand: "#F25623"

    // neutral inks for text on an arbitrary wallpaper. bright, with soft +
    // dim steps. pair with a drop shadow for contrast on any backdrop.
    readonly property color ink:     "#f5f3ff"
    readonly property color inkSoft: "#d2d7ef"
    readonly property color inkDim:  "#9aa3c8"
    readonly property color shadow:  Qt.rgba(0, 0, 0, 0.55)

    // carbon-dossier surface for the desktop menu (chrome should read as the
    // same shell as the pill). cool near-black panel + faint hairline for
    // rules / registration ticks + faint ink for eyebrow labels.
    readonly property color cardTop: Wallust.matchWallpaper ? Wallust.base : "#1a1b26"
    readonly property color cardBot: Wallust.matchWallpaper ? Wallust.deep : "#13131b"
    readonly property color hair:    Qt.rgba(245 / 255, 243 / 255, 255 / 255, 0.13)
    readonly property color faint:   Qt.rgba(245 / 255, 243 / 255, 255 / 255, 0.42)

    readonly property string font:   "Inter"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string mono:   "JetBrainsMono Nerd Font"

    // motion: short + smooth. OutExpo mirrors the shell's open curve.
    readonly property int quick:  140
    readonly property int medium: 260
    readonly property int slow:   420
    readonly property int ease:   Easing.OutExpo
}
