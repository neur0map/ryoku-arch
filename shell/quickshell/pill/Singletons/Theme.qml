pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property color verm:     "#c0442b"
    readonly property color vermLit:  "#e0563b"
    readonly property color vermDeep: "#a3371f"
    readonly property color cream:    "#e6d6cb"
    readonly property color bright:   "#fff6f0"
    readonly property color dim:      "#8a7d74"
    readonly property color cardTop:  "#2e231b"
    readonly property color cardBot:  "#221813"
    readonly property color border:   "#3a2a22"
    readonly property color shadow:     Qt.rgba(0, 0, 0, 0.55)
    readonly property color tileBg:   "#211711"
    readonly property color subtle:   "#b9a99e"
    readonly property color faint:    "#6f635b"
    readonly property color iconDim:  "#cdbfb4"
    readonly property color hair:     Qt.rgba(230/255, 214/255, 203/255, 0.13)
    readonly property color sheen:    Qt.rgba(230/255, 214/255, 203/255, 0.07)
    readonly property color vermDim:   "#8a5440"
    readonly property color vermDimDeep: "#5a3526"
    readonly property color vermBurn:  "#8a2c14"
    readonly property color tickRest:  "#cbb6a3"
    readonly property color threadBg:  Qt.rgba(0.94, 0.88, 0.84, 0.13)
    readonly property color flameCore: "#ffd9c2"
    readonly property color flameGlow: "#ff9a64"

    /**
     * Flame canvas ramp: literal hex strings (color type won't work), fed
     * directly to Canvas addColorStop/strokeStyle. A color property serializes
     * to #aarrggbb and corrupts the gradient render.
     */
    readonly property string flameInk:   "#f0795a"
    readonly property string flameEmber: "#7e2812"
    readonly property string flameBurn:  "#8a2c14"
    readonly property string flameTip:   "#ffb38a"
    readonly property color todayWarm: "#ffb38a"
    readonly property color ghost:     "#594636"
    readonly property color frameBg:      Qt.rgba(0.94, 0.88, 0.84, 0.055)
    readonly property color frameBorder:  Qt.rgba(0.94, 0.88, 0.84, 0.10)
    readonly property color creamMenu:     Qt.rgba(0.902, 0.839, 0.796, 0.82)
    readonly property real shadowOpacity: 0.5
    readonly property string font: "Inter"
    readonly property string fontJp: "Zen Kaku Gothic New"

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
