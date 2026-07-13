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
// geometry = unscaled base pixels at 1080p. osd values are multiplied by the
// per-monitor scale `s` where they're read; frameRadius / frameBorder sit in
// Hyprland's gaps ring and stay unscaled, matching the hand-tuned originals.
Singleton {
    id: root

    // frame = rounded screen border the popouts swell out of.
    property alias frameRadius:    adapter.frameRadius
    property alias frameBorder:    adapter.frameBorder
    property alias frameEnabled:   adapter.frameEnabled
    property alias frameSmoothing: adapter.frameSmoothing
    property alias frameOpacity:   adapter.frameOpacity
    property alias shadowStrength: adapter.shadowStrength
    property alias shadowSize:     adapter.shadowSize
    // frame off collapses the border ring (and its shadow) to nothing, so a bar
    // sits flush at the screen edge; the frameBorder setting is kept intact.
    readonly property real effectiveFrameBorder: frameEnabled ? frameBorder : 50

    // surface = warm dark fill shared by the frame and its popouts. one blob field,
    // so a single colour reads as one continuous surface.
    property alias surfaceColor:   adapter.surfaceColor

    // osd = the volume/brightness flash and notification toasts: small edge
    // windows that share the frame surface. osdRadius rounds their corners,
    // osdOpacity fades them.
    property alias osdRadius:  adapter.osdRadius
    property alias osdOpacity: adapter.osdOpacity

    // bar = the shell's resting face, drawn on the frame's thickened edge
    // (Bar.qml). barPosition is "top" or "bottom"; barStyle picks the skin,
    // one of noctalia and caelestia (carried from the reference shells) or the
    // native aegis, stele, triptych, and delos (a single floating island). barHeight = the band the edge swells by (scaled per
    // monitor). barShowTitle / barShowMedia / barShowStatus gate the focused
    // window title, the now-playing module, and the status cluster.
    // barOccupiedWorkspaces shows only workspaces with windows (plus the
    // active one), hiding empty numbers.
    property alias barEnabled:            adapter.barEnabled
    property alias barPosition:           adapter.barPosition
    property alias barStyle:              adapter.barStyle
    property alias barHeight:             adapter.barHeight
    property alias barShowTitle:          adapter.barShowTitle
    property alias barShowMedia:          adapter.barShowMedia
    property alias barShowStatus:         adapter.barShowStatus
    property alias barOccupiedWorkspaces: adapter.barOccupiedWorkspaces
    // delos = the single floating-island bar. islandModules names the modules
    // it carries, in display order, and the user picks them (power is not one:
    // Super+Esc opens it). islandEdge / islandAlong persist where it last
    // docked; islandHidden whether it is tucked to a nub.
    property alias islandEdge:    adapter.islandEdge
    property alias islandAlong:   adapter.islandAlong
    property alias islandHidden:  adapter.islandHidden
    property alias islandModules: adapter.islandModules
    property alias islandRadius:  adapter.islandRadius

    // sidebars = the two "Aside" panels that blob-melt out of the left and right
    // screen edges, each summoned by hovering that side's top corner (or an IPC
    // toggle). LEFT carries features (stash and future add-ons); RIGHT carries
    // system controls + glance panes. sidebarLeftPanes / sidebarRightPanes pick
    // which panes each shows and their order; sidebarClickless opens on hover
    // (else click); sidebarWidth / sidebarCornerSize size the panel + corner.
    property alias sidebarLeftEnabled:  adapter.sidebarLeftEnabled
    property alias sidebarRightEnabled: adapter.sidebarRightEnabled
    property alias sidebarLeftPanes:    adapter.sidebarLeftPanes
    property alias sidebarRightPanes:   adapter.sidebarRightPanes
    property alias sidebarClickless:    adapter.sidebarClickless
    property alias sidebarWidth:        adapter.sidebarWidth
    property alias sidebarCornerSize:   adapter.sidebarCornerSize

    // roundness = the shell-wide inner corner radius (the "Global" shape knob).
    // every internal tile, card, row and chip reads Theme.radius, which follows
    // this, so the whole shell shares one rounded shape that echoes the frame's
    // melt. 0 restores the old brutalist sharp corners.
    property alias roundness: adapter.roundness

    // typography: UI font family (Theme.font reads this) + a scale that grows
    // or shrinks the whole shell (the bar text and the surfaces around it),
    // keeping the readout legible without overflow.
    property alias fontFamily: adapter.fontFamily
    property alias fontScale:  adapter.fontScale

    // weather: an explicit location override (a city name; blank = auto-locate by
    // IP) and the temperature unit ("auto" follows the locale, else "celsius" /
    // "fahrenheit"). the Weather singleton reads both.
    property alias weatherLocation: adapter.weatherLocation
    property alias weatherUnit:     adapter.weatherUnit

    // matchWallpaper: when on, every shell surface (frame, bar, popouts, plus
    // desktop widgets, plugin tiles, the window switcher)
    // follows the live wallust palette instead of the static Tokyo Night
    // tokens. sourced from theme.json (`FollowWallpaper`, the single colour
    // master shared with the daemon and window borders). on by default.
    property alias matchWallpaper: themeAdapter.followWallpaper

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

        JsonAdapter {
            id: adapter
            property real frameRadius: 9
            property real frameBorder: 59
            property bool frameEnabled: true
            property real frameSmoothing: 8
            property real frameOpacity: 1
            property real shadowStrength: 0.63
            property real shadowSize: 12
            property color surfaceColor: "#0f1115"
            property real osdRadius: 28
            property real osdOpacity: 1
            property bool barEnabled: true
            property string barPosition: "top"
            property string barStyle: "noctalia"
            property real barHeight: 30
            property bool barShowTitle: true
            property bool barShowMedia: true
            property bool barShowStatus: true
            property bool barOccupiedWorkspaces: true
            property string islandEdge: "top"
            property real islandAlong: -1
            property bool islandHidden: false
            property var islandModules: ["workspaces", "clock", "date", "media"]
            property real islandRadius: 17
            property string fontFamily: "JetBrainsMono Nerd Font"
            property real fontScale: 1.3
            property bool sidebarLeftEnabled: true
            property bool sidebarRightEnabled: true
            property var sidebarLeftPanes: ["stash"]
            property var sidebarRightPanes: ["notifications", "calendar", "media", "weather", "recording"]
            property bool sidebarClickless: true
            property real sidebarWidth: 340
            property real sidebarCornerSize: 34
            property real roundness: 10
            property string weatherLocation: ""
            property string weatherUnit: "auto"
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

    // write the live adapter back to shell.json. the delos island calls this
    // when it settles on a new edge so the dock survives a restart.
    function persist() { file.writeAdapter(); }

    // seed only on a genuine first run (nothing to load), so a slow or failed
    // load can't overwrite a present file with defaults.
    Component.onCompleted: {
        if (!file.text()) file.writeAdapter();
        if (!brandFile.text()) brandFile.writeAdapter();
    }
}
