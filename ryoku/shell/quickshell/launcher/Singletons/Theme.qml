pragma Singleton
import QtQuick
import Quickshell

Singleton {
    // Accent follows the wallpaper when matchWallpaper is on (a core feature);
    // the fixed fallback is the Ryoku brand vermillion (website tokens.css).
    readonly property color brand:    Config.matchWallpaper ? Wallust.accent : "#e2342a"
    readonly property color verm:     brand
    readonly property color vermLit:  Config.matchWallpaper ? Qt.lighter(Wallust.accent, 1.22) : "#e83b30"
    readonly property color vermDeep: Config.matchWallpaper ? Qt.darker(Wallust.accent, 1.3) : "#b81f19"
    readonly property color sun:      "#e2342a"
    readonly property color gold:     "#d9a441"
    // warm-white text ramp (website --ink).
    readonly property color cream:    "#e6dccb"
    readonly property color bright:   "#f3ede1"
    readonly property color dim:      "#8f8770"
    // near-black canvas (website --paper), or wallust surfaces when matching.
    readonly property color cardTop:  Config.matchWallpaper ? Wallust.base : "#16110b"
    readonly property color cardBot:  Config.matchWallpaper ? Wallust.deep : "#0f0c07"
    readonly property color border:   Config.matchWallpaper ? Wallust.line : Qt.rgba(243/255, 237/255, 225/255, 0.14)
    readonly property color lineStrong: Qt.rgba(236/255, 226/255, 205/255, 0.40)
    readonly property color shadow:   "#000000"
    readonly property color tileBg:   Config.matchWallpaper ? Wallust.elevated : "#1b150e"
    readonly property color subtle:   "#c7bfae"
    readonly property color faint:    "#5c5249"
    readonly property color iconDim:  "#8f8770"
    readonly property color hair:     Qt.rgba(243/255, 237/255, 225/255, 0.12)
    readonly property color sheen:    Qt.rgba(243/255, 237/255, 225/255, 0.06)
    readonly property color vermDim:  "#b05a43"
    readonly property color vermDimDeep: "#65342b"
    readonly property color vermBurn: "#8f321d"
    readonly property color tickRest: "#8f8770"
    readonly property color threadBg: Qt.rgba(226/255, 52/255, 42/255, 0.13)
    readonly property color flameCore: "#ffd2bf"
    readonly property color flameGlow: "#ff9e64"

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes
     * to #aarrggbb and corrupts the gradient render.
     */
    readonly property string flameInk:   "#e83b30"
    readonly property string flameEmber: "#7a2a1a"
    readonly property string flameBurn:  "#8f321d"
    readonly property string flameTip:   "#ffd2bf"
    readonly property color todayWarm: "#ff9e64"
    readonly property color ghost:     "#414868"
    // Rest-card sky: fixed day/night scene colours, deliberately independent of
    // the accent so the sun stays golden and the night cool on any wallpaper.
    readonly property color sunGold:  "#ffc777"
    readonly property color moonGlow: "#7aa2f7"
    readonly property color moonDisc: "#c8d3f5"
    readonly property color frameBg:     Qt.rgba(226/255, 52/255, 42/255, 0.10)
    readonly property color frameBorder: Qt.rgba(243/255, 237/255, 225/255, 0.18)
    readonly property color creamMenu:   Qt.rgba(230/255, 220/255, 203/255, 0.82)
    readonly property real shadowOpacity: 0.5
    // type stack + brutalist geometry, the website language.
    readonly property string display: "Fraunces"
    readonly property string font: Config.fontFamily.length > 0 ? Config.fontFamily : "Space Grotesk"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string mono: "JetBrainsMono Nerd Font"
    // brand mark + name, user-overridable via ~/.config/ryoku/brand.json (Shell ->
    // Global). defaults to the 力 seal / "Ryoku". BrandMark renders `mark`, or
    // `markSource` (an image) when set. Ryoku's own apps never read these.
    readonly property string mark: Config.markText.length > 0 ? Config.markText : "\u529b"
    readonly property string markSource: Config.markImage
    readonly property bool markTint: Config.markTint
    readonly property string brandName: Config.brandName.length > 0 ? Config.brandName : "Ryoku"
    readonly property int radius: 0
    readonly property real border2: 1
    readonly property int shadowStep: 6

    /**
     * MPRIS trackArtists arrives as a JS array from some players and as a
     * plain string from others (Spotify); calling join on the string throws
     * and kills the whole binding. Handles both, falls back to trackArtist.
     */
    function joinArtists(artists, single) {
        if (artists && typeof artists.join === "function" && artists.length > 0)
            return artists.join(", ");
        if (artists && String(artists).length > 0)
            return String(artists);
        return single ? String(single) : "";
    }
}
