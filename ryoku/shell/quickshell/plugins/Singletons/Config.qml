pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live shell appearance config = single source of truth for the look knobs
// Ryoku Settings -> Shell edits, plus the shipped defaults the shell falls
// back to. JSON at ~/.config/ryoku/shell.json, watched: save in Settings
// retunes the running shell on the next file event, no reload. defaults
// here are canonical, Ryoku Settings mirrors them for reset-to-default
// and seeds nothing of its own.
//
// geometry = unscaled base pixels at 1080p. island values get *s (per-monitor
// scale) where they're read; frame radius + border sit in Hyprland's gaps ring
// and stay unscaled (matches the hand-tuned originals).
Singleton {
    id: root

    // frame: the rounded screen border the pill swells out of.
    property alias frameRadius:    adapter.frameRadius
    property alias frameBorder:    adapter.frameBorder
    property alias frameSmoothing: adapter.frameSmoothing
    property alias frameOpacity:   adapter.frameOpacity
    property alias shadowStrength: adapter.shadowStrength
    property alias shadowSize:     adapter.shadowSize

    // surface: warm dark fill shared by frame + pill + island. one blob field,
    // so a single colour reads as one continuous surface.
    property alias surfaceColor:   adapter.surfaceColor

    // island: morphing top pill + the music bud that grows beside it.
    property alias islandWidth:      adapter.islandWidth
    property alias islandHeight:     adapter.islandHeight
    property alias islandRestCorner: adapter.islandRestCorner
    property alias islandOpenCorner: adapter.islandOpenCorner
    property alias islandGap:        adapter.islandGap
    property alias islandSmoothing:  adapter.islandSmoothing
    property alias islandOpacity:    adapter.islandOpacity

    // island variant + rest visibility:
    //   islandStyle    = "island" (pill fused into the top frame, default)
    //                  | "floating" (detached pill below the frame)
    //                  | "none" (no resting island; surfaces + keybinds still work)
    //   islandAutohide = hide at rest, reveal on hover of the top centre.
    //                    applies to "island" + "floating"; "none" is always hidden.
    property alias islandStyle:    adapter.islandStyle
    property alias islandAutohide: adapter.islandAutohide

    // top bar: opt-in bar drawn on the frame's thickened top edge (Bar.qml),
    // shown in place of the resting island. on -> the island never shows at
    // rest (surfaces + keybinds still summon the pill). Ryoku Settings ->
    // Shell -> Bar toggles it.
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
            property bool barEnabled: false
        }
    }

    // seed only on a real first run (no content to load), so a slow or failed
    // load never overwrites a present file from defaults.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
