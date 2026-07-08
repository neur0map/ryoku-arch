pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// shell surface palette matched to the wallpaper's terminal background. when
// Ryoku Settings -> Shell -> Match wallpaper is on (read here from
// theme.json.FollowWallpaper, the single colour master shared with the daemon
// and window borders), surfaces follow the live wallust palette
// (~/.cache/wallust/colors.json), so the shell reads as the same colour as an
// open terminal. `base` = the kitty background exactly; elevated/deep/line
// shift its value to keep the depth hierarchy. defaults = the Ryoku brand
// palette so things look right before the first wallust run.
Singleton {
    readonly property bool  matchWallpaper: shellCfg.followWallpaper
    readonly property color base:     shade(palette.background)
    readonly property color elevated: tone(base, 0.05)
    readonly property color deep:     tone(base, -0.03)
    readonly property color line:     tone(base, 0.14)
    readonly property color accent:   legible(vivid(palette.color4), elevated, 3.0)

    // Tone-map the wallpaper background into the shell's dark band, hue kept:
    // HSV value inside [0.08, 0.26] passes through, pure black lifts to a soft
    // near-black, brighter compresses to just past the ceiling; saturation caps
    // at 0.55 so a saturated wallpaper reads as a deep tint, never neon.
    function shade(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var s = Math.min(c.hsvSaturation, 0.55);
        var v = c.hsvValue;
        if (v < 0.08)      v = 0.08;
        else if (v > 0.26) v = 0.26 + (v - 0.26) * 0.06;
        return Qt.hsva(hue, s, v, 1);
    }

    // WCAG relative luminance / contrast, for the legible() guard below.
    function relLum(c) {
        function lin(u) { return u <= 0.04045 ? u / 12.92 : Math.pow((u + 0.055) / 1.055, 2.4); }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b);
    }
    function contrast(a, b) {
        var la = relLum(a), lb = relLum(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Walk fg toward white until it clears `target` against bg; already-passing
    // colors return unchanged.
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

    // shift a colour's HSV value by dv (hue/sat kept), so a ramp from the
    // wallpaper background sits at predictable depths.
    function tone(c, dv) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        return Qt.hsva(hue, c.hsvSaturation, Math.max(0, Math.min(1, c.hsvValue + dv)), 1);
    }
    // lift sat, floor brightness, so an accent reads as colour not mud.
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
            id: palette
            property color background: "#16110b"
            property color color4: "#e2342a"
        }
    }

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: shellCfg
            property bool followWallpaper: true
        }
    }
}
