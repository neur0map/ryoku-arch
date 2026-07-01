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
    readonly property color base:     palette.background
    readonly property color elevated: tone(palette.background, 0.05)
    readonly property color deep:     tone(palette.background, -0.03)
    readonly property color line:     tone(palette.background, 0.14)
    readonly property color accent:   vivid(palette.color4)

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
            property color background: "#1a1b26"
            property color color4: "#F25623"
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
