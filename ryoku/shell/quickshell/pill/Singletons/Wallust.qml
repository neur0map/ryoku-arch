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
 * `base` keeps the terminal (kitty) background's hue but is tone-mapped into the
 * shell's dark band by shade(): the terminal may go bright crimson on a saturated
 * red wallpaper, the shell surface may not -- it clamps dark enough for the
 * static light text (Theme.bright/cream/subtle) to stay readable. Backgrounds
 * already inside the band pass through untouched, so on normal dark palettes the
 * shell still reads as exactly the terminal surface. `elevated`/`deep`/`line`
 * shift its value for the pill's depth hierarchy. `accent` is the vivified lead
 * tint, lightened by legible() just enough to clear 3:1 against the elevated
 * surface -- a red accent on a red-derived surface drifts to salmon instead of
 * vanishing. Defaults are the Ryoku brand palette so the pill looks right before
 * the first wallust run; they sit inside the band, so they render unchanged.
 */
Singleton {
    // The shell surface ramp, matched to the wallpaper's terminal background,
    // tone-mapped into the dark band (tiles lighter, recesses darker, hairline
    // borders lighter still).
    readonly property color base:     shade(adapter.background)
    readonly property color elevated: tone(base, 0.05)
    readonly property color deep:     tone(base, -0.03)
    readonly property color line:     tone(base, 0.14)
    // Alias kept for the blob fill in shell.qml.
    readonly property color surface:  base
    readonly property color accent:   legible(vivid(adapter.color4), elevated, 3.0)
    readonly property color accent2:  legible(vivid(adapter.color5), elevated, 3.0)
    // Raw color4, the exact hue Hyprland's border uses (hypr-colors.lua active = color4).
    readonly property color border:   adapter.color4

    // Tone-map the wallpaper background into the shell's dark band, hue kept.
    // HSV value inside [0.08, 0.26] passes through; pure black lifts to a soft
    // near-black; brighter than the ceiling compresses hard (6% of the
    // overshoot) so neon and pastel wallpapers land just past the ceiling
    // instead of piling onto one flat tone. Saturation caps at 0.55 so a
    // saturated wallpaper reads as a deep tint, never neon.
    function shade(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var s = Math.min(c.hsvSaturation, 0.55);
        var v = c.hsvValue;
        if (v < 0.08)      v = 0.08;
        else if (v > 0.26) v = 0.26 + (v - 0.26) * 0.06;
        return Qt.hsva(hue, s, v, 1);
    }

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

    // WCAG relative luminance.
    function relLum(c) {
        function lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4); }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }

    // WCAG contrast ratio between two colors.
    function contrast(a, b) {
        var la = relLum(a), lb = relLum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Walk fg toward white in 18% steps (max 8) until it clears `target`
    // against bg. Colors that already pass return unchanged, so well-behaved
    // palettes and the no-wallust defaults render exactly as before.
    function legible(fg, bg, target) {
        var r = fg.r, g = fg.g, b = fg.b;
        for (var i = 0; i < 8; i++) {
            var c = Qt.rgba(r, g, b, 1);
            if (contrast(c, bg) >= target) return c;
            r += (1 - r) * 0.18;
            g += (1 - g) * 0.18;
            b += (1 - b) * 0.18;
        }
        return Qt.rgba(r, g, b, 1);
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
