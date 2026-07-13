pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Switcher appearance config, a focused twin of the shell's Config: the two look
// knobs this surface reads (the wallpaper-match colour master and the UI font)
// come from the same JSON the pill, launcher and overview watch, so the switcher
// retunes with the rest of the shell. Read only.
Singleton {
    property alias matchWallpaper: themeAdapter.followWallpaper
    property alias fontFamily:     adapter.fontFamily
    property alias fontScale:      adapter.fontScale

    // brand: the desktop's mark + name, user-overridable from Ryoku Settings ->
    // Shell -> Global. a small cross-cutting identity master (like theme.json).
    // markText is the glyph/short-text seal (default 力); markImage an optional
    // image path that wins over the text; markTint recolours a single-colour
    // image to the accent; name is the wordmark ("Ryoku") shown in chrome copy.
    property alias markText:  brandAdapter.markText
    property alias markImage: brandAdapter.markImage
    property alias markTint:  brandAdapter.markTint
    property alias brandName: brandAdapter.name

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

    // brand identity master (mark + name), the cross-cutting identity shared with
    // doctor, the Hub editor and the rest of the shell. the always-on
    // pill seeds it; these defaults cover its absence, so no seed is written here.
    FileView {
        id: brandFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/brand.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: brandAdapter
            property string markText: "力"
            property string markImage: ""
            property bool markTint: true
            property string name: "Ryoku"
        }
    }
}
