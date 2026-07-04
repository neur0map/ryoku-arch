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
 * `base` is exactly the terminal (kitty) background, so the shell reads as the
 * same surface as an open terminal; `elevated`/`deep`/`line` shift its value for
 * the pill's depth hierarchy. `accent` is the vivified lead tint for highlights.
 * Defaults are the Ryoku brand palette so the pill looks right before the first
 * wallust run; wallust yields a dark background for these palettes, keeping the
 * pill's light text legible.
 */
Singleton {
    // The shell surface ramp, matched to the wallpaper's terminal background. base
    // is exactly the terminal (kitty) background from colors.json; the rest shift
    // its value to keep the pill's depth (tiles lighter, recesses darker, hairline
    // borders lighter still).
    readonly property color base:     adapter.background
    readonly property color elevated: tone(adapter.background, 0.05)
    readonly property color deep:     tone(adapter.background, -0.03)
    readonly property color line:     tone(adapter.background, 0.14)
    // Alias kept for the blob fill in shell.qml.
    readonly property color surface:  base
    readonly property color accent:   vivid(adapter.color4)
    readonly property color accent2:  vivid(adapter.color5)
    // Raw color4, the exact hue Hyprland's border uses (hypr-colors.lua active = color4).
    readonly property color border:   adapter.color4

    // Shift a colour's HSV value by dv (hue and saturation kept), so a ramp from
    // the wallpaper background sits at predictable depths.
    function tone(c, dv) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        return Qt.hsva(hue, c.hsvSaturation, Math.max(0, Math.min(1, c.hsvValue + dv)), 1);
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
            property color background: "#16110b"
            property color color4: "#e2342a"
            property color color5: "#e83b30"
        }
    }
}
