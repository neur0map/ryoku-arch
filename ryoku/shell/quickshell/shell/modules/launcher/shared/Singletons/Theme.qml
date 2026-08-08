pragma Singleton
import QtQuick
import Quickshell
import Ryoku.Ui.Singletons as Ui
import "../lib/contrast.js" as Contrast

Singleton {
    // Accent follows the wallpaper when matchWallpaper is on (a core feature);
    // the fixed fallback is the Ryoku brand vermillion (website tokens.css).
    readonly property color brand:    Config.matchWallpaper ? Scheme.accent : "#e2342a"
    readonly property color verm:     brand
    readonly property color vermLit:  Config.matchWallpaper ? Qt.lighter(Scheme.accent, 1.22) : "#e83b30"
    readonly property color vermDeep: Config.matchWallpaper ? Qt.darker(Scheme.accent, 1.3) : "#b81f19"
    readonly property color gold:     "#d9a441"
    // warm-white text ramp (website --ink).
    readonly property color cream:    Ui.Tokens.ink
    readonly property color bright:   Ui.Tokens.ink
    // near-black canvas (website --paper), or palette surfaces when matching.
    readonly property color cardTop:  Config.matchWallpaper ? Scheme.base : "#16110b"
    readonly property color border:   Config.matchWallpaper ? Scheme.line : Qt.rgba(243/255, 237/255, 225/255, 0.14)
    readonly property color lineStrong: Qt.rgba(236/255, 226/255, 205/255, 0.40)
    readonly property color shadow:   "#000000"
    readonly property color tileBg:   Config.matchWallpaper ? Scheme.elevated : "#1b150e"
    readonly property color subtle:   Ui.Tokens.inkDim
    readonly property color faint:    Ui.Tokens.inkMuted
    readonly property color iconDim:  Ui.Tokens.inkMuted
    readonly property color hair:     Ui.Tokens.lineSoft
    readonly property color sheen:    Ui.Tokens.tint5
    readonly property color vermDim:  "#b05a43"
    readonly property color vermDimDeep: "#65342b"
    readonly property color vermBurn: "#8f321d"
    readonly property color tickRest: "#8f8770"
    readonly property color threadBg: Qt.rgba(226/255, 52/255, 42/255, 0.13)
    readonly property color flameCore: "#ffd2bf"
    readonly property color flameGlow: "#ff9e64"

    // Shutter roles. The drawer stays in the same dark surface band as the
    // desktop while the promoted lead borrows the shared bone/Material role.
    // Only the thin provider rail carries route colour.
    readonly property color drawer: Ui.Tokens.paper
    readonly property color drawerRaised: Ui.Tokens.paperLift
    readonly property color frame: Ui.Tokens.lineStrong
    readonly property color leadContainer: Config.matchWallpaper
        ? Ui.Tokens.bone : cream
    readonly property color onLead: leadForeground(leadContainer)
    readonly property color onLeadDim: leadMetadata(onLead, leadContainer)
    readonly property color modeActive: leadContainer
    readonly property color onModeActive: onLead
    readonly property color modeIdle: Qt.rgba(0, 0, 0, 0.76)
    readonly property color providerApps: Ui.Tokens.sun
    readonly property color providerFind: Config.matchWallpaper ? Scheme.accent2 : vermDim
    readonly property color providerRecent: Ui.Tokens.inkMuted
    readonly property color providerOther: Ui.Tokens.inkDim

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
    // Hero sky: fixed day/night scene colours, deliberately independent of
    // the accent so the sun stays golden and the night cool on any wallpaper.
    readonly property color sunGold:  "#ffc777"
    readonly property color moonGlow: "#7aa2f7"
    readonly property color moonDisc: "#c8d3f5"
    readonly property color creamMenu:   Qt.rgba(230/255, 220/255, 203/255, 0.82)
    readonly property real shadowOpacity: 0.5
    // type stack + brutalist geometry, the website language.
    readonly property string display: "Fraunces"
    readonly property string font: Ui.Tokens.ui
    readonly property string mono: Ui.Tokens.mono
    readonly property int radius: 0
    readonly property real border2: 1
    readonly property int shadowStep: 6

    function qmlColor(value) {
        return Qt.rgba(value.r, value.g, value.b, value.a);
    }

    function leadForeground(background) {
        return qmlColor(Contrast.readableForeground(
            background, Ui.Tokens.inkOnBone, bright, 4.5));
    }

    function leadMetadata(foreground, background) {
        return qmlColor(Contrast.mutedForeground(
            foreground, background, 4.5));
    }

    function contrastInk(background) {
        return leadForeground(background);
    }

    function providerRail(providerId, type) {
        var provider = String(providerId || "");
        var kind = String(type || "").toLowerCase();
        if (provider === "apps") return providerApps;
        if (provider === "find" || kind === "file" || kind === "folder"
                || kind === "image" || kind === "video")
            return providerFind;
        if (provider === "recent") return providerRecent;
        return providerOther;
    }

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
