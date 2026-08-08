pragma Singleton
import QtQuick
import Quickshell

// Shared widget tokens: the design-language geometry, motion and type, with
// every colour resolved from the daemon palette through Scheme so the clock,
// its card and the right-click menu follow the active theme (a fixed named
// scheme or the live wallpaper) instead of a hardcoded tint. `brand` stays the
// fixed vermillion identity (the 力 seal and the clock's deliberate "brand"
// accent option); `accent` is the live system accent the interactive chrome
// paints with. motion = the shell's morph curve (OutExpo).
Singleton {
    // brand: fixed vermillion identity. Never themes -- that is the point. Used
    // by the 力 seal and the clock's deliberate "brand" accent option.
    readonly property color brand: "#e2342a"
    readonly property color sun:   "#e2342a"
    readonly property color gold:  "#d9a441"

    // accent: the live system accent (the palette's primary role). The menu
    // chrome -- selected chips, the "on" value, toggles, sliders, borders and
    // resize grips -- paints with this so it retints on every scheme change.
    readonly property color accent: Scheme.accent

    // inks for the menu, which sits on its own card: the palette's own on-surface
    // roles, correct against `surface` below.
    readonly property color ink:     Scheme.onSurface
    readonly property color inkDim:  Scheme.onSurfaceVariant
    readonly property color inkSoft: Qt.rgba((ink.r + inkDim.r) / 2,
                                             (ink.g + inkDim.g) / 2,
                                             (ink.b + inkDim.b) / 2, 1)
    readonly property color shadow:  Qt.rgba(0, 0, 0, 0.55)

    // inks for a widget with no card under it: resolved against its own patch of
    // wallpaper rather than a surface that is not there.
    function inkOn(l)     { return Scheme.inkOn(l); }
    function inkDimOn(l)  { return Scheme.inkDimOn(l); }
    function inkSoftOn(l) { return Scheme.inkSoftOn(l); }
    function accentOn(l)  { return Scheme.accentOn(l); }

    // carbon-dossier surface for the desktop menu: the palette surface over a
    // recessed floor, with ink-derived hairline + faint eyebrow tints so the
    // chrome follows the theme.
    readonly property color cardTop: Scheme.surface
    readonly property color cardBot: Scheme.deep
    readonly property color hair:    Qt.rgba(ink.r, ink.g, ink.b, 0.13)
    readonly property color faint:   Qt.rgba(ink.r, ink.g, ink.b, 0.42)
    readonly property color lineStrong: Qt.rgba(ink.r, ink.g, ink.b, 0.42)

    // ── menu surface: the right-click chrome, in the sidebar design idiom ──
    // an opaque lifted plate (the palette surface); rows and chips wash with
    // ink-derived tints so hover and press read on any palette.
    readonly property color surface:   Scheme.surface
    readonly property color line:      Qt.rgba(ink.r, ink.g, ink.b, 0.16)
    readonly property color tile:      Qt.rgba(ink.r, ink.g, ink.b, 0.06)
    readonly property color tileHover: Qt.rgba(ink.r, ink.g, ink.b, 0.10)
    readonly property color tilePress: Qt.rgba(ink.r, ink.g, ink.b, 0.16)

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
    // rounded corners for the menu card and its tiles (the sidebar radiusWidget
    // idiom); the sharp `radius: 0` above stays the clock-face default.
    readonly property int radiusWidget: 14
    readonly property int radiusTile:   9

    // motion: short + smooth. OutExpo mirrors the shell's open curve.
    readonly property int quick:  140
    readonly property int medium: 260
    readonly property int slow:   420
    readonly property int ease:   Easing.OutExpo
}
