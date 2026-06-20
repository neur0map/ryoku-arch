pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live shell appearance config: the single source of truth for the look knobs
 * the Ryoku Hub's Shell Settings edits, and the shipped defaults the shell falls
 * back to. Persisted as JSON at ~/.config/ryoku/shell.json and watched, so a
 * save in the Hub retunes the running shell on the next file event, with no
 * reload. The defaults here are canonical; the Hub mirrors them for its
 * reset-to-default and seeds nothing of its own.
 *
 * Geometry is unscaled base pixels at 1080p. The island values are multiplied by
 * the per-monitor scale `s` where they are read; the frame radius and border sit
 * in Hyprland's gaps ring and stay unscaled, matching the hand-tuned originals.
 */
Singleton {
    id: root

    // Frame: the rounded screen border the pill swells out of.
    property alias frameRadius:    adapter.frameRadius
    property alias frameBorder:    adapter.frameBorder
    property alias frameSmoothing: adapter.frameSmoothing
    property alias frameOpacity:   adapter.frameOpacity
    property alias shadowStrength: adapter.shadowStrength
    property alias shadowSize:     adapter.shadowSize

    // Surface: the warm dark fill the frame, the pill and the island share. They
    // live in one blob field, so a single colour reads as one continuous surface.
    property alias surfaceColor:   adapter.surfaceColor

    // Island: the morphing top pill and the music bud that grows beside it.
    property alias islandWidth:      adapter.islandWidth
    property alias islandHeight:     adapter.islandHeight
    property alias islandRestCorner: adapter.islandRestCorner
    property alias islandOpenCorner: adapter.islandOpenCorner
    property alias islandGap:        adapter.islandGap
    property alias islandSmoothing:  adapter.islandSmoothing
    property alias islandOpacity:    adapter.islandOpacity

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
        }
    }

    // Seed only on a genuine first run (no content to load), so a slow or failed
    // load never overwrites a present file from defaults.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
