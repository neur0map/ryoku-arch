pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live shell appearance config. one source of truth for the look knobs Ryoku
// Settings' Shell section edits, plus the shipped defaults the shell falls back
// to. JSON at ~/.config/ryoku/shell.json, watched, so a save in Settings
// retunes the running shell on the next file event. no reload. defaults here
// are canonical; Settings mirrors them for reset-to-default and seeds nothing
// of its own.
//
// geometry = unscaled base pixels at 1080p. island values are multiplied by the
// per-monitor scale `s` where they're read; frameRadius / frameBorder sit in
// Hyprland's gaps ring and stay unscaled, matching the hand-tuned originals.
Singleton {
    id: root

    // where the ryoku-cmd-* leaf helpers live (deployed from hyprland/scripts).
    // they are not on PATH, so the launcher invokes them by full path.
    readonly property string scriptsDir: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/"
    // frame = rounded screen border the pill swells out of.
    property alias frameRadius:    adapter.frameRadius
    property alias frameBorder:    adapter.frameBorder
    property alias frameSmoothing: adapter.frameSmoothing
    property alias frameOpacity:   adapter.frameOpacity
    property alias shadowStrength: adapter.shadowStrength
    property alias shadowSize:     adapter.shadowSize

    // surface = warm dark fill shared by frame + pill + island. one blob field,
    // so a single colour reads as one continuous surface.
    property alias surfaceColor:   adapter.surfaceColor

    // island = morphing top pill + the music bud beside it.
    property alias islandWidth:      adapter.islandWidth
    property alias islandHeight:     adapter.islandHeight
    property alias islandRestCorner: adapter.islandRestCorner
    property alias islandOpenCorner: adapter.islandOpenCorner
    property alias islandGap:        adapter.islandGap
    property alias islandSmoothing:  adapter.islandSmoothing
    property alias islandOpacity:    adapter.islandOpacity

    // islandStyle = island (pill fused into top frame, default) | floating
    // (detached, floats below the frame) | none (no resting island, surfaces
    // and keybinds still work).
    // islandAutohide: hide at rest, reveal on top-centre hover. applies to
    // island + floating; "none" is always hidden.
    property alias islandStyle:    adapter.islandStyle
    property alias islandAutohide: adapter.islandAutohide

    // top bar = opt-in bar drawn on the frame's thickened top edge (Bar.qml),
    // in place of the resting island. when on, the island never shows at rest
    // (surfaces / keybinds still summon the pill). Settings -> Shell -> Bar.
    property alias barEnabled: adapter.barEnabled

    // typography: UI font family (Theme.font reads this) + a scale that grows
    // or shrinks the whole pill (text and the island around it). keeps the
    // readout legible on a dense panel without overflow.
    property alias fontFamily: adapter.fontFamily
    property alias fontScale:  adapter.fontScale

    // matchWallpaper: when on, every shell surface (frame, island, popouts,
    // every surface, plus desktop widgets, plugin tiles, the window switcher)
    // follows the live wallust palette instead of the static Tokyo Night
    // tokens. sourced from theme.json (`FollowWallpaper`, the single colour
    // master shared with the daemon and window borders). on by default.
    property alias matchWallpaper: themeAdapter.followWallpaper

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property real frameRadius: 16
            property real frameBorder: 66
            property real frameSmoothing: 30
            property real frameOpacity: 1
            property real shadowStrength: 0.5
            property real shadowSize: 26
            property color surfaceColor: "#1a1b26"
            property real islandWidth: 108
            property real islandHeight: 38
            property real islandRestCorner: 18
            property real islandOpenCorner: 22
            property real islandGap: 8
            property real islandSmoothing: 24
            property real islandOpacity: 1
            property string islandStyle: "island"
            property bool islandAutohide: false
            property bool barEnabled: false
            property string fontFamily: "Inter"
            property real fontScale: 1.0
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

    // seed only on a genuine first run (nothing to load), so a slow or failed
    // load can't overwrite a present file with defaults.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
