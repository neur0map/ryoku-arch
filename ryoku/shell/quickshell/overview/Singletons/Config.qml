pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Overview appearance config, a focused twin of the shell's Config: the two look
// knobs this surface reads (the wallpaper-match colour master and the UI font)
// come from the same JSON the pill and launcher watch, so the overview retunes
// with the rest of the shell. No writes: the overview only ever reads.
Singleton {
    property alias matchWallpaper: themeAdapter.followWallpaper
    property alias fontFamily:     adapter.fontFamily
    property alias fontScale:      adapter.fontScale

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: adapter
            property string fontFamily: "Space Grotesk"
            property real fontScale: 1.0
        }
    }

    // The colour-source master (single source shared with the daemon, window
    // borders, and shell chrome): true = follow the wallpaper palette.
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter { id: themeAdapter; property bool followWallpaper: true }
    }
}
