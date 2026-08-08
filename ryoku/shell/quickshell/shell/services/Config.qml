pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.FrameBars

// live shell appearance config. one source of truth for the look knobs Ryoku
// Settings' Shell section edits, plus the shipped defaults the shell falls back
// to. JSON at ~/.config/ryoku/shell.json, watched, so a save in Settings
// retunes the running shell on the next file event. no reload. defaults here
// are canonical; Settings mirrors them for reset-to-default and seeds nothing
// of its own.
//
// geometry = unscaled base pixels at 1080p. osd values are multiplied by the
// per-monitor scale `s` where they're read.
Singleton {
    id: root

    // frame = the painted border band. Its enable, opacity, band thickness and
    // corner radius are live knobs; the rail geometry lives in frameBars.
    property alias frameEnabled:   adapter.frameEnabled
    property alias frameOpacity:   adapter.frameOpacity
    property alias frameThickness: adapter.frameThickness
    property alias frameCorner:    adapter.frameCorner

    // osd = the volume/brightness flash and notification toasts: small edge
    // windows that share the frame surface. osdRadius rounds their corners,
    // osdOpacity fades them.
    property alias osdRadius:  adapter.osdRadius
    property alias osdOpacity: adapter.osdOpacity

    property alias frameBars: adapter.frameBars
    readonly property var normalizedFrameBars: FrameBars.normalize(frameBars, BarCatalog, MenuCatalog)

    // barStyle: which bar design renders. "qsbar" is the default QS Bar top bar
    // (a shipped folder style under modules/bar/barstyles/qsbar); "sumi" is the
    // built-in painted left rail; any other id is an installed store folder
    // style. Each owns its own bar, popouts and settings. Default qsbar.
    property alias barStyle: adapter.barStyle

    // obi: per-widget visibility for the Obi bar style, edited in Bar Studio.
    // A map of widgetId -> bool; an absent key reads as shown, so the bar is
    // full by default and only an explicit false hides a widget. Each folder
    // style gets its own key here, the extensible per-style settings store.
    property alias obi: adapter.obi
    property alias nacre: adapter.nacre
    property alias qsbar: adapter.qsbar
    readonly property var normalizedNacre: NacreConfig.normalize(nacre)

    // typography: a scale that grows or shrinks the whole shell (the bar text
    // and the surfaces around it), keeping the readout legible without overflow.
    property alias fontScale:  adapter.fontScale

    // weather: an explicit location override (a city name; blank = auto-locate by
    // IP) and the temperature unit ("auto" follows the locale, else "celsius" /
    // "fahrenheit"). the Weather singleton reads both.
    property alias weatherLocation: adapter.weatherLocation
    property alias weatherUnit:     adapter.weatherUnit

    // matchWallpaper: when on, every shell surface (frame, bar, popouts, plus
    // desktop widgets, plugin tiles, the window switcher)
    // follows the live palette instead of the static Tokyo Night
    // tokens. sourced from theme.json (`FollowWallpaper`, the single colour
    // master shared with the daemon and window borders). on by default.
    property alias matchWallpaper: themeAdapter.followWallpaper

    // themePalette: the active static theme's palette (role token -> hex), which
    // the daemon resolves and writes as a top-level key in shell.json; absent for
    // the two dynamic variants (Default, Wallpaper). The shared JsonAdapter can't
    // represent a removed key -- it only overwrites keys still present -- so read
    // presence straight from the frame text: a missing key resolves to null, and
    // Theme.namedScheme then falls back to the wallpaper or base palette.
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
    // Shell -> Global. a small cross-cutting identity master (like theme.json).
    // markText is the glyph/short-text seal (default 力); markImage an optional
    // image path that wins over the text; markTint recolours a single-colour
    // image to the accent; name is the wordmark ("Ryoku") shown in chrome copy.
    // Ryoku's own apps (the Hub, ryo* apps) never read this and keep the 力 brand.
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
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: root.refreshThemePalette()

        JsonAdapter {
            id: adapter
            property bool frameEnabled: true
            property real frameOpacity: 1
            property real frameThickness: 2
            property real frameCorner: 8
            property real osdRadius: 0
            property real osdOpacity: 1
            property real fontScale: 1.3
            property string weatherLocation: ""
            property string weatherUnit: "auto"
            property var frameBars: FrameBars.defaultConfig()
            property string barStyle: "qsbar"
            property var obi: ({})
            property var nacre: NacreConfig.defaultConfig()
            property var qsbar: ({})
        }
    }

    // The colour-source master lives in theme.json (single source: the daemon,
    // window borders and shell chrome all read it). true = follow the wallpaper.
    FileView {
        id: themeFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/theme.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter { id: themeAdapter; property bool followWallpaper: true }
    }

    // brand identity master (mark + name), shared with doctor and the
    // Hub's Shell -> Global editor. seeded once on first run below.
    FileView {
        id: brandFile
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/brand.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        JsonAdapter {
            id: brandAdapter
            property string markText: "力"
            property string markImage: ""
            property bool markTint: true
            property string name: "Ryoku"
        }
    }


    // seed only on a genuine first run (nothing to load), so a slow or failed
    // load can't overwrite a present file with defaults.
    Component.onCompleted: {
        if (!file.text()) file.writeAdapter();
        if (!brandFile.text()) brandFile.writeAdapter();
        root.refreshThemePalette();
    }
}
