pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * The live palette, for the Desktop Widgets previews. Reads the same
 * ~/.cache/ryoku/colors.json the desktop widgets read, so a preview shows the
 * real wallpaper colours rather than a stand-in ramp. Mirrors the widgets'
 * Scheme singleton (each Quickshell config carries its own thin palette reader);
 * the defaults are the Ryoku brand palette.
 */
Singleton {
    id: root

    readonly property color accent:  vivid(adapter.color4)
    readonly property color accent2: vivid(adapter.color5)

    readonly property var ramp: [
        vivid(adapter.color1),
        vivid(adapter.color3),
        vivid(adapter.color2),
        vivid(adapter.color6),
        vivid(adapter.color4),
        vivid(adapter.color5)
    ]

    function vivid(c) {
        var hue = c.hsvHue < 0 ? 0 : c.hsvHue;
        var sat = c.hsvSaturation < 0.06 ? 0 : Math.min(1, c.hsvSaturation * 1.2 + 0.06);
        return Qt.hsva(hue, sat, Math.max(c.hsvValue, 0.74), 1);
    }

    function colorAt(t) {
        var s = root.ramp;
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
        return Qt.rgba(a.r + (b.r - a.r) * f, a.g + (b.g - a.g) * f, a.b + (b.b - a.b) * f, 1);
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/ryoku/colors.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property color color1: "#f7768e"
            property color color2: "#9ece6a"
            property color color3: "#e0af68"
            property color color4: "#7aa2f7"
            property color color5: "#bb9af7"
            property color color6: "#7dcfff"
        }
    }
}
