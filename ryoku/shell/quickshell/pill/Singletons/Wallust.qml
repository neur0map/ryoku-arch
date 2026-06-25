pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The live wallust palette for the pill/shell, used only when Ryoku Settings ->
 * Shell -> Match wallpaper is on. wallust rewrites ~/.cache/wallust/colors.json on
 * every wallpaper change (see wallust.toml) and this watches it, so the pill's
 * surface fill and accent retune to whatever is on screen.
 *
 * `surface` is deliberately *not* the raw wallpaper background: the pill carries
 * light text, so the fill is forced dark (the wallpaper's hue at a fixed low
 * value), keeping the readout legible under any wallpaper, light or dark. `accent`
 * is the vivified lead tint for the pill's highlights. Defaults are the Ryoku
 * brand palette so the pill looks right before the first wallust run.
 */
Singleton {
    readonly property color surface: tintedDark(adapter.background)
    readonly property color accent:  vivid(adapter.color4)
    readonly property color accent2: vivid(adapter.color5)

    // Keep the wallpaper's hue but pin the fill dark and lightly saturated, so the
    // surface reads as a tinted dark, never a bright panel that swallows the text.
    function tintedDark(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var sat = c.hsvSaturation < 0.05 ? 0 : Math.min(0.5, c.hsvSaturation);
        return Qt.hsva(hue, sat, 0.13, 1);
    }

    // Lift saturation and floor brightness so an accent reads as colour, not mud,
    // however desaturated the wallpaper is. Greys (no hue) are only brightened.
    function vivid(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var sat = c.hsvSaturation < 0.06 ? 0 : Math.min(1, c.hsvSaturation * 1.2 + 0.06);
        return Qt.hsva(hue, sat, Math.max(c.hsvValue, 0.74), 1);
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/wallust/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property color background: "#1a1b26"
            property color color4: "#F25623"
            property color color5: "#ff7a45"
        }
    }
}
