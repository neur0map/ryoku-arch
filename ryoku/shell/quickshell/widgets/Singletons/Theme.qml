pragma Singleton
import QtQuick
import Quickshell

// shared widget tokens. brand constant, type family, a small neutral ink
// ramp. widgets sit on the wallpaper so text leans bright/cool and colour
// accents come from Wallust; brand orange stays fixed (the one deliberate
// highlight). motion = the shell's morph curve (OutExpo), so a widget
// feels like the same desktop as the pill.
Singleton {
    // brand: fixed vermillion, used sparingly. the one accent that never themes.
    readonly property color brand: "#e2342a"
    readonly property color sun:   "#e2342a"
    readonly property color gold:  "#d9a441"

    // neutral inks for text on an arbitrary wallpaper. bright, with soft +
    // dim steps. pair with a drop shadow for contrast on any backdrop.
    readonly property color ink:     "#f5f3ff"
    readonly property color inkSoft: "#d2d7ef"
    readonly property color inkDim:  "#9aa3c8"
    readonly property color shadow:  Qt.rgba(0, 0, 0, 0.55)

    // carbon-dossier surface for the desktop menu (chrome reads as the shell:
    // the website's warm near-black + hairline + faint ink for eyebrows).
    readonly property color cardTop: Wallust.matchWallpaper ? Wallust.base : "#16110b"
    readonly property color cardBot: Wallust.matchWallpaper ? Wallust.deep : "#0f0c07"
    readonly property color hair:    Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.13)
    readonly property color faint:   Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.42)
    readonly property color lineStrong: Qt.rgba(236 / 255, 226 / 255, 205 / 255, 0.40)

    readonly property string display: "Fraunces"
    readonly property string font:   "Space Grotesk"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string mono:   "JetBrainsMono Nerd Font"
    // brand mark + name, user-overridable via ~/.config/ryoku/brand.json (Shell ->
    // Global). defaults to the 力 seal / "Ryoku". BrandMark renders `mark`, or
    // `markSource` (an image) when set. Ryoku's own apps never read these.
    readonly property string mark: Config.markText.length > 0 ? Config.markText : "\u529b"
    readonly property string markSource: Config.markImage
    readonly property bool markTint: Config.markTint
    readonly property string brandName: Config.brandName.length > 0 ? Config.brandName : "Ryoku"
    readonly property int radius: 0

    // motion: short + smooth. OutExpo mirrors the shell's open curve.
    readonly property int quick:  140
    readonly property int medium: 260
    readonly property int slow:   420
    readonly property int ease:   Easing.OutExpo
}
