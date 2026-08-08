pragma Singleton
import QtQuick
import Quickshell

/**
 * Switcher style tokens, a focused twin of the shell Theme so the surface reads
 * like the rest of the desktop. Every colour resolves through the same
 * three-layer fallback, highest priority first:
 *
 *   named scheme  ->  live wallpaper  ->  compiled default
 *
 * - compiled default: the Solitude Dark base palette, shown when no dynamic
 *   theme is active.
 * - live wallpaper: the Scheme singleton, active while Config.matchWallpaper is
 *   on; a wallpaper change retunes every role live.
 * - named scheme: the active static preset's palette (Config.themePalette,
 *   resolved by the Go theme daemon into shell.json); null while a dynamic
 *   variant is selected.
 *
 * The Material "on" roles are declared plain and bound through Binding elements:
 * QML parses an inline `onSurface:` as a change-handler for the sibling
 * `surface` property and drops the binding, so naming the property in a Binding
 * sidesteps that grab.
 */
Singleton {
    id: root

    readonly property bool matchWallpaper: Config.matchWallpaper
    property var namedScheme: Config.themePalette

    function role(key, base) {
        if (namedScheme && namedScheme[key] !== undefined)
            return namedScheme[key];
        if (matchWallpaper)
            return Scheme[key];
        return base;
    }

    // --- 30 Material colour roles (compiled defaults: Solitude Dark) ----------
    readonly property color surface:                 role("surface", "#181616")
    readonly property color surfaceVariant:          role("surfaceVariant", "#1a1d1f")
    readonly property color surfaceContainerLowest:  role("surfaceContainerLowest", "#101315")
    readonly property color surfaceContainerLow:     role("surfaceContainerLow", "#0e0f10")
    readonly property color surfaceContainer:        role("surfaceContainer", "#2c2f32")
    readonly property color surfaceContainerHigh:    role("surfaceContainerHigh", "#3d4144")
    readonly property color surfaceContainerHighest: role("surfaceContainerHighest", "#4b4e55")
    readonly property color inverseSurface:          role("inverseSurface", "#cacccc")
    readonly property color inverseOnSurface:        role("inverseOnSurface", "#101315")
    readonly property color surfaceTint:             role("surfaceTint", "#798186")
    readonly property color primary:                 role("primary", "#e2342a")
    readonly property color primaryContainer:        role("primaryContainer", "#1a1d1f")
    readonly property color secondary:               role("secondary", "#a8adb0")
    readonly property color secondaryContainer:      role("secondaryContainer", "#1a1d1f")
    readonly property color tertiary:                role("tertiary", "#de6145")
    readonly property color tertiaryContainer:       role("tertiaryContainer", "#1a1d1f")
    readonly property color error:                   role("error", "#de6145")
    readonly property color errorContainer:          role("errorContainer", "#1a1d1f")
    readonly property color outline:                 role("outline", "#3f3b36")
    readonly property color outlineVariant:          role("outlineVariant", "#343d41")

    property color onSurface
    property color onSurfaceVariant
    property color onPrimary
    property color onPrimaryContainer
    property color onSecondary
    property color onSecondaryContainer
    property color onTertiary
    property color onTertiaryContainer
    property color onError
    property color onErrorContainer
    Binding { target: root; property: "onSurface";            value: root.role("onSurface", "#c5c9c5") }
    Binding { target: root; property: "onSurfaceVariant";     value: root.role("onSurfaceVariant", "#a6a69c") }
    Binding { target: root; property: "onPrimary";            value: root.role("onPrimary", "#101315") }
    Binding { target: root; property: "onPrimaryContainer";   value: root.role("onPrimaryContainer", "#a8adb0") }
    Binding { target: root; property: "onSecondary";          value: root.role("onSecondary", "#101315") }
    Binding { target: root; property: "onSecondaryContainer"; value: root.role("onSecondaryContainer", "#a8adb0") }
    Binding { target: root; property: "onTertiary";           value: root.role("onTertiary", "#101315") }
    Binding { target: root; property: "onTertiaryContainer";  value: root.role("onTertiaryContainer", "#de6145") }
    Binding { target: root; property: "onError";              value: root.role("onError", "#101315") }
    Binding { target: root; property: "onErrorContainer";     value: root.role("onErrorContainer", "#de6145") }

    readonly property color shadow: role("shadow", "#000000")
    readonly property color scrim:  role("scrim", "#000000")

    // --- overlay tints (selection / hover fills over the surface) -------------
    readonly property color frameBg:     Qt.rgba(primary.r, primary.g, primary.b, 0.12)
    readonly property color frameBorder: Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.18)

    // --- sizing (compiled defaults) -------------------------------------------
    readonly property int  radiusWidget: 8
    readonly property int  radiusWindow: 8
    readonly property int  borderWidth: 2
    readonly property int  paddingSm: 4
    readonly property int  paddingMd: 8
    readonly property int  paddingLg: 16

    // --- fonts ----------------------------------------------------------------
    readonly property string fontPrimary: "Space Grotesk"
    readonly property int fontSm: 14
    readonly property int fontMd: 16
    readonly property int fontLg: 18
    readonly property int fontXl: 26
    readonly property string display: "Fraunces"
    readonly property string mono:    "JetBrainsMono Nerd Font"
    readonly property string fontJp:  "Noto Sans CJK JP"

    // brand mark, user-overridable via ~/.config/ryoku/brand.json.
    readonly property string mark: Config.markText.length > 0 ? Config.markText : "\u529b"

    // paper-and-ink alias: the single red accent (seal / sun) for the switcher.
    readonly property color seal: primary
    readonly property color sun:  primary

    // ── qsbar-matching style tokens: the switcher reads in the bar's own
    // language (warm paper, mono labels, sep hairlines, seal-lift tiles). ──
    readonly property color sumi:       onSurfaceVariant
    readonly property color sumiHi:     Qt.rgba(onSurfaceVariant.r * 0.45 + onSurface.r * 0.55, onSurfaceVariant.g * 0.45 + onSurface.g * 0.55, onSurfaceVariant.b * 0.45 + onSurface.b * 0.55, 1.0)
    readonly property color sep:        Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.18)
    readonly property color fillIdle:   Qt.rgba(0, 0, 0, 0.12)
    readonly property color fillHover:  Qt.rgba(seal.r, seal.g, seal.b, 0.10)
    readonly property color fillActive: Qt.rgba(seal.r, seal.g, seal.b, 0.18)
    readonly property color frameWeak:  Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.05)
    readonly property int   pillRadius:   12
    readonly property int   islandRadius: 16
    readonly property int   tileRadius:   10
    readonly property string ui: "Space Grotesk"

    // inversion is Ryoku's only emphasis: an active plate flips to bone with
    // dark ink on it. lineStrong is the overlay-separating hairline.
    readonly property color bone:       onSurface
    readonly property color inkOnBone:  surface
    readonly property color lineStrong: Qt.rgba(onSurface.r, onSurface.g, onSurface.b, 0.42)
}
