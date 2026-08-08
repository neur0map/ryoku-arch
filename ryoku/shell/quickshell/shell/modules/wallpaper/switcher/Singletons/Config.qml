pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Switcher appearance config, a focused twin of the shell's Config: the look
// knobs this surface reads come from the same JSON the pill, launcher and
// overview watch, so the switcher retunes with the rest of the shell. Read only.
Singleton {
    id: root

    property alias frameOpacity:   adapter.frameOpacity
    property alias fontScale:      adapter.fontScale

    // matchWallpaper: the colour-source master (theme.json), shared with the
    // daemon, window borders and the rest of the shell chrome.
    property alias matchWallpaper: themeAdapter.followWallpaper

    // themePalette: the active static theme's palette (role token -> hex), which
    // the daemon resolves and writes as a top-level key in shell.json; absent for
    // the two dynamic variants. The shared JsonAdapter cannot represent a removed
    // key, so read presence straight from the frame text: a missing key resolves
    // to null and Theme.namedScheme falls back to the wallpaper or base palette.
    property var themePalette: null
    function refreshThemePalette() {
        var pal = null;
        var t = file.text();
        if (t) {
            try {
                var o = JSON.parse(t);
                if (o && typeof o.themePalette === "object" && o.themePalette !== null)
                    pal = o.themePalette;
            } catch (e) {
            }
        }
        themePalette = pal;
    }

    // brand: the desktop's mark + name, user-overridable from Ryoku Settings ->
    // Shell -> Global (a small cross-cutting identity master).
    property alias markText:  brandAdapter.markText
    property alias markImage: brandAdapter.markImage
    property alias markTint:  brandAdapter.markTint
    property alias brandName: brandAdapter.name

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.refreshThemePalette()
        JsonAdapter {
            id: adapter
            property real frameOpacity: 1
            property real fontScale: 1.3
        }
    }

    // The colour-source master (single source shared with the daemon, window
    // borders and shell chrome): true = follow the wallpaper palette.
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter { id: themeAdapter; property bool followWallpaper: true }
    }

    // brand identity master (mark + name), shared with doctor, the Hub editor and
    // the rest of the shell. the always-on pill seeds it; these defaults cover its
    // absence, so no seed is written here.
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

    Component.onCompleted: root.refreshThemePalette()
}
