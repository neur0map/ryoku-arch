pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color brand:    Config.matchWallpaper ? Wallust.accent : "#e2342a"
    readonly property color verm:     brand
    readonly property color vermLit:  Config.matchWallpaper ? Qt.lighter(Wallust.accent, 1.22) : "#e83b30"
    readonly property color vermDeep: Config.matchWallpaper ? Qt.darker(Wallust.accent, 1.3) : "#b81f19"
    readonly property color sun:      "#e2342a"
    readonly property color gold:     "#d9a441"
    readonly property color cream:    "#e6dccb"
    readonly property color bright:   "#f3ede1"
    // a foreground that stays legible on the accent fill: dark ink when the
    // accent is light (a pale wallpaper pick), warm-white when it is dark, so a
    // toggle icon never washes out against Theme.brand.
    readonly property color onAccent: (0.299 * brand.r + 0.587 * brand.g + 0.114 * brand.b) > 0.6 ? "#100d08" : bright
    readonly property color dim:      "#8f8770"
    readonly property color cardTop:  Config.matchWallpaper ? Wallust.base : "#16110b"
    readonly property color cardBot:  Config.matchWallpaper ? Wallust.deep : "#0f0c07"
    readonly property color border:   Config.matchWallpaper ? Wallust.line : Qt.rgba(243/255, 237/255, 225/255, 0.14)
    readonly property color lineStrong: Qt.rgba(236/255, 226/255, 205/255, 0.40)
    readonly property color shadow:   Qt.rgba(0, 0, 0, 0.62)
    // brutalist hard offset shadow: opaque black, no blur (the website's
    // --shadow / hub's shadow). `shadow` above stays semi-transparent for the
    // soft blurred drop shadows (tray, wallpaper tiles).
    readonly property color shadowHard: "#000000"
    readonly property int shadowOffset: 3
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
    readonly property color frameBg:     Qt.rgba(226/255, 52/255, 42/255, 0.10)
    readonly property color frameBorder: Qt.rgba(243/255, 237/255, 225/255, 0.18)
    readonly property color creamMenu:   Qt.rgba(230/255, 220/255, 203/255, 0.82)
    readonly property real shadowOpacity: 0.5
    readonly property string display: "Fraunces"
    readonly property string font: Config.fontFamily.length > 0 ? Config.fontFamily : "Space Grotesk"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string mono: "JetBrainsMono Nerd Font"
    // inner corner radius, shell-wide: follows the Global "roundness" knob so
    // every tile, card, row and chip shares one rounded shape that echoes the
    // frame's melt. 0 restores the old brutalist sharp corners; true circles
    // (status dots, slider knobs) set their own radius: width/2 and are unaffected.
    readonly property int radius: Math.round(Config.roundness)
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
