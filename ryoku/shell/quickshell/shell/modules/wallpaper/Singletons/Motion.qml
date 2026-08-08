pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Desktop backdrop motion. Only the wallpaper swap is animated: a 200 ms linear
// crossfade on each revision (contract 08 sec 5, TRANSITION_DURATION_MS; the
// shell's Motion.wallpaperFade). reduce motion or low power collapses it to an
// instant cut, matching the shell Motion so a weak GPU stops repainting.
Singleton {
    readonly property bool reduce: perf.lowPowerMode || perf.reduceMotion
    readonly property int wallpaperFade: reduce ? 0 : 200

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: perf
            property bool lowPowerMode: false
            property bool reduceMotion: false
        }
    }
}
