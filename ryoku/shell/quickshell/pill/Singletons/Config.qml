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

    // top bar = the default face, drawn on the frame's thickened edge
    // (Bar.qml). barPosition picks the edge: a "top" bar replaces the resting
    // island (the island still summons for surfaces, toasts and the OSD);
    // bottom/left/right bars live on their own edge and the island keeps its
    // usual top-centre life beside them. barStyle picks the skin: "noctalia" or
    // "caelestia", the two reference dialects the modules are carried from.
    // barHeight = the band the edge swells by (scaled per monitor, like
    // island geometry). barShowTitle / barShowMedia / barShowStatus gate the
    // focused-window title, the now-playing readout, and the status cluster.
    property alias barEnabled:    adapter.barEnabled
    property alias barPosition:   adapter.barPosition
    property alias barStyle:      adapter.barStyle
    property alias barHeight:     adapter.barHeight
    property alias barShowTitle:  adapter.barShowTitle
    property alias barShowMedia:  adapter.barShowMedia
    property alias barShowStatus: adapter.barShowStatus

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
            property real frameRadius: 9
            property real frameBorder: 59
            property real frameSmoothing: 8
            property real frameOpacity: 1
            property real shadowStrength: 0.63
            property real shadowSize: 12
            property color surfaceColor: "#0f1115"
            property real islandWidth: 109
            property real islandHeight: 34
            property real islandRestCorner: 6
            property real islandOpenCorner: 28
            property real islandGap: 0
            property real islandSmoothing: 24
            property real islandOpacity: 1
            property string islandStyle: "floating"
            property bool islandAutohide: true
            property bool barEnabled: true
            property string barPosition: "top"
            property string barStyle: "noctalia"
            property real barHeight: 30
            property bool barShowTitle: true
            property bool barShowMedia: true
            property bool barShowStatus: true
            property string fontFamily: "JetBrainsMono Nerd Font"
            property real fontScale: 1.3
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
