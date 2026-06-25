pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color brand:    "#F25623"
    readonly property color verm:     brand
    readonly property color vermLit:  "#ff7a45"
    readonly property color vermDeep: "#c4411d"
    readonly property color cream:    "#c0caf5"
    readonly property color bright:   "#e0e6ff"
    readonly property color dim:      "#7aa2f7"
    readonly property color cardTop:  "#1a1b26"
    readonly property color cardBot:  "#16161e"
    readonly property color border:   "#2f3549"
    readonly property color shadow:   Qt.rgba(0, 0, 0, 0.62)
    readonly property color tileBg:   "#1f2335"
    readonly property color subtle:   "#a9b1d6"
    readonly property color faint:    "#565f89"
    readonly property color iconDim:  "#9aa5ce"
    readonly property color hair:     Qt.rgba(192/255, 202/255, 245/255, 0.13)
    readonly property color sheen:    Qt.rgba(192/255, 202/255, 245/255, 0.07)
    readonly property color vermDim:  "#b05a43"
    readonly property color vermDimDeep: "#65342b"
    readonly property color vermBurn: "#8f321d"
    readonly property color tickRest: "#9aa5ce"
    readonly property color threadBg: Qt.rgba(122/255, 162/255, 247/255, 0.13)
    readonly property color flameCore: "#ffd2bf"
    readonly property color flameGlow: "#ff9e64"

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes
     * to #aarrggbb and corrupts the gradient render.
     */
    readonly property string flameInk:   "#ff7a45"
    readonly property string flameEmber: "#7a2a1a"
    readonly property string flameBurn:  "#8f321d"
    readonly property string flameTip:   "#ffd2bf"
    readonly property color todayWarm: "#ff9e64"
    readonly property color ghost:     "#414868"
    readonly property color frameBg:     Qt.rgba(122/255, 162/255, 247/255, 0.10)
    readonly property color frameBorder: Qt.rgba(122/255, 162/255, 247/255, 0.18)
    readonly property color creamMenu:   Qt.rgba(192/255, 202/255, 245/255, 0.82)
    readonly property real shadowOpacity: 0.5
    readonly property string font: "Inter"
    readonly property string fontJp: "Noto Sans CJK JP"
    readonly property string mono: "JetBrainsMono Nerd Font"

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
