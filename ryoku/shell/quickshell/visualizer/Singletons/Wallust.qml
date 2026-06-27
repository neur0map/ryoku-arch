pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live wallust palette for the visualiser. wallust rewrites
// ~/.cache/wallust/colors.json on every wallpaper change (see wallust.toml);
// this watches it so the spectrum retunes to whatever is on screen. defaults
// are the Ryoku brand palette, so the visualiser looks right before the
// first wallust run and never falls back to grey.
//
// stops = ordered low->high freq ramp the bars sample with colorAt(t). each
// stop is vivified, so a muted wallpaper still glows.
Singleton {
    id: root

    readonly property color background: adapter.background
    readonly property color accent: vivid(adapter.color4)

    readonly property var stops: [
        vivid(adapter.color1),
        vivid(adapter.color3),
        vivid(adapter.color2),
        vivid(adapter.color6),
        vivid(adapter.color4),
        vivid(adapter.color5)
    ]

    // lift saturation, floor brightness, so the spectrum reads as colour, not
    // mud, no matter how desaturated the wallpaper is. greys (no measurable
    // hue) are only brightened, never tinted.
    function vivid(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var sat = c.hsvSaturation < 0.06 ? 0 : Math.min(1, c.hsvSaturation * 1.25 + 0.08);
        return Qt.hsva(hue, sat, Math.max(c.hsvValue, 0.72), 1);
    }

    // linear-interp the ramp at t in [0,1].
    function colorAt(t) {
        var s = root.stops;
        var n = s.length;
        if (n === 0)
            return root.accent;
        if (n === 1)
            return s[0];
        var x = Math.max(0, Math.min(0.999999, t)) * (n - 1);
        var i = Math.floor(x);
        var f = x - i;
        var a = s[i];
        var b = s[i + 1];
        return Qt.rgba(a.r + (b.r - a.r) * f,
                       a.g + (b.g - a.g) * f,
                       a.b + (b.b - a.b) * f, 1);
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
            property color background: "#16161e"
            property color foreground: "#c0caf5"
            property color color0: "#16161e"
            property color color1: "#f7768e"
            property color color2: "#9ece6a"
            property color color3: "#e0af68"
            property color color4: "#7aa2f7"
            property color color5: "#bb9af7"
            property color color6: "#7dcfff"
            property color color7: "#c0caf5"
            property color color8: "#414868"
            property color color9: "#f7768e"
            property color color10: "#9ece6a"
            property color color11: "#e0af68"
            property color color12: "#7aa2f7"
            property color color13: "#bb9af7"
            property color color14: "#7dcfff"
            property color color15: "#c0caf5"
        }
    }
}
