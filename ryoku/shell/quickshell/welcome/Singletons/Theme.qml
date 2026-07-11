pragma Singleton
import QtQuick
import Quickshell

// Welcome walkthrough palette: the website's Greek-noir language, the same tokens
// the Hub carries. A first-run window shown once on a fresh login, so it keeps the
// brand vermillion fixed (wallust is not yet meaningful on a first boot) and reads
// the same on any wallpaper. Mirrors hub/quickshell/Singletons/Theme.qml; near-black
// canvas, warm-white type, one vermillion accent, gold as kintsugi only, brutalist
// geometry (sharp corners, hairline borders, hard offset shadows).
Singleton {
    // brand: one vermillion, sparingly + boldly.
    readonly property color brand:     "#e2342a"
    readonly property color ember:     "#e83b30"
    readonly property color emberDeep: "#b81f19"
    readonly property color sun:       "#e2342a"
    readonly property color sunDeep:   "#b81f19"
    readonly property color onAccent:  "#fbeee2"   // text on a vermillion fill
    readonly property color gold:      "#d9a441"   // kintsugi seams, sparingly

    // canvas + surfaces. flat; depth from hairlines + hard shadow.
    readonly property color bgTop:    "#16110b"
    readonly property color bgBot:    "#0f0c07"
    readonly property color surface:  "#1b150e"
    readonly property color surfaceLo:"#140f09"
    readonly property color keyTop:   "#221a12"
    readonly property color keyBot:   "#17110b"
    readonly property color line:     Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.14)
    readonly property color lineSoft: Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.06)
    readonly property color lineStrong: Qt.rgba(236 / 255, 226 / 255, 205 / 255, 0.40)
    readonly property color shadow:   "#000000"
    readonly property color frameBg:  Qt.rgba(226 / 255, 52 / 255, 42 / 255, 0.10)
    readonly property color hair:     Qt.rgba(243 / 255, 237 / 255, 225 / 255, 0.12)

    // content backing over the art: warm near-black glass (flat, no blur), so copy
    // stays legible while the backdrop breathes around it.
    readonly property color panel:    Qt.rgba(16 / 255, 13 / 255, 8 / 255, 0.66)
    readonly property color panelSoft: Qt.rgba(16 / 255, 13 / 255, 8 / 255, 0.42)

    // text (warm neutrals, site --ink ramp).
    readonly property color bright:   "#f3ede1"
    readonly property color cream:    "#e6dccb"
    readonly property color subtle:   "#c7bfae"
    readonly property color dim:      "#8f8770"
    readonly property color faint:    "#5c5249"

    // type stack, mirrors the website.
    readonly property string display: "Fraunces"
    readonly property string font:    "Space Grotesk"
    readonly property string fontJp:  "Noto Sans CJK JP"
    readonly property string mono:    "JetBrainsMono Nerd Font"

    // brutalist geometry: sharp corners, hairline borders, hard offset shadows.
    readonly property int radius:       0
    readonly property int radiusChip:   0
    readonly property real border:      1
    readonly property int shadowStep:   6
    readonly property int shadowStepLg: 8

    // motion. short + smooth; OutExpo ~ the site's cubic-bezier(0.22,1,0.36,1).
    readonly property int quick:  120
    readonly property int medium: 260
    readonly property int slow:   440
    readonly property int ease:   Easing.OutExpo
}
