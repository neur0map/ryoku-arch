pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The live wallust palette, mirrored for the overview surface the same way the
 * pill and launcher mirror it (each qs config has its own singleton root). Used
 * only when Match wallpaper is on. wallust rewrites ~/.cache/wallust/colors.json
 * on every wallpaper change; this watches it so the overview's fill and accent
 * track whatever is on screen. Defaults are the Ryoku brand palette so it looks
 * right before the first wallust run.
 */
Singleton {
    readonly property color base:     adapter.background
    readonly property color elevated: tone(adapter.background, 0.05)
    readonly property color deep:     tone(adapter.background, -0.03)
    readonly property color line:     tone(adapter.background, 0.14)
    readonly property color accent:   vivid(adapter.color4)

    // Shift a colour's HSV value by dv (hue + saturation kept), so a ramp from
    // the wallpaper background sits at predictable depths.
    function tone(c, dv) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        return Qt.hsva(hue, c.hsvSaturation, Math.max(0, Math.min(1, c.hsvValue + dv)), 1);
    }

    // Lift saturation and floor brightness so the accent reads as colour, not
    // mud, however desaturated the wallpaper is. Greys are only brightened.
    function vivid(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var sat = c.hsvSaturation < 0.06 ? 0 : Math.min(1, c.hsvSaturation * 1.2 + 0.06);
        return Qt.hsva(hue, sat, Math.max(c.hsvValue, 0.74), 1);
    }

    FileView {
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/wallust/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: adapter
            property color background: "#16110b"
            property color color4: "#e2342a"
        }
    }
}
