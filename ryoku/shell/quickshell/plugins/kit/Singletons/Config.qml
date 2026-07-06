pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live shell appearance config. single source of truth for the look knobs
// Ryoku Settings' Shell section edits, plus the shipped defaults the shell
// falls back to. JSON at ~/.config/ryoku/shell.json, watched, so a save in
// Settings retunes the running shell on the next file event (no reload).
// defaults here are canonical: Settings mirrors them for reset and seeds
// nothing of its own.
//
// geometry = unscaled base px at 1080p. island values get multiplied by the
// per-monitor `s` at the read site; frame radius/border live in Hyprland's
// gaps ring and stay unscaled, matching the hand-tuned originals.
Singleton {
    id: root

    // frame = the rounded screen border the pill swells out of.
    property alias frameRadius:    adapter.frameRadius
    property alias frameBorder:    adapter.frameBorder
    property alias frameSmoothing: adapter.frameSmoothing
    property alias frameOpacity:   adapter.frameOpacity
    property alias shadowStrength: adapter.shadowStrength
    property alias shadowSize:     adapter.shadowSize

    // surface = warm dark fill shared by frame + pill + island. one blob
    // field, one colour, so it reads as one continuous surface.
    property alias surfaceColor:   adapter.surfaceColor

    // island = morphing top pill + the music bud growing beside it.
    property alias islandWidth:      adapter.islandWidth
    property alias islandHeight:     adapter.islandHeight
    property alias islandRestCorner: adapter.islandRestCorner
    property alias islandOpenCorner: adapter.islandOpenCorner
    property alias islandGap:        adapter.islandGap
    property alias islandSmoothing:  adapter.islandSmoothing
    property alias islandOpacity:    adapter.islandOpacity

    // islandStyle:
    //   "island"   = pill fused into the top frame (default)
    //   "floating" = detached pill, floats below the frame
    //   "none"     = no resting island; surfaces + keybinds still work
    // islandAutohide: hide at rest, reveal on top-centre hover. applies to
    // "island" and "floating"; "none" is always hidden.
    property alias islandStyle:    adapter.islandStyle
    property alias islandAutohide: adapter.islandAutohide

    // optional bar drawn on the frame's thickened top edge (Bar.qml), shown
    // in place of the resting island. when on, island never shows at rest
    // (surfaces + keybinds still summon the pill). toggled by Ryoku Settings
    // -> Shell -> Bar.
    property alias barEnabled: adapter.barEnabled

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
        }
    }

    // seed only on a real first run (no content to load), so a slow/failed
    // load can't overwrite a present file from defaults.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
