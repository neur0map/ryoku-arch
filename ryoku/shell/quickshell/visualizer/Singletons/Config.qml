pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Live config for the desktop visualiser, the single source of truth for the
 * knobs Ryoku Settings' Shell section edits and the shipped defaults it falls
 * back to. Persisted as JSON at ~/.config/ryoku/visualizer.json and watched, so a
 * save in Ryoku Settings (or a Super+M toggle) retunes the running spectrum on the next
 * file event, with no reload. The defaults here are canonical; Ryoku Settings mirrors
 * them for its reset-to-default.
 *
 * Fractions are of the monitor height or the per-band slot, matching how the
 * spectrum sizes itself, so they stay right across resolutions.
 */
Singleton {
    id: root

    property alias enabled:    adapter.enabled     // master on/off (also Super+M)
    property alias bars:       adapter.bars         // cava band count
    property alias height:     adapter.height       // tallest bar, fraction of screen height
    property alias thickness:  adapter.thickness    // bar width, fraction of its slot
    property alias bloom:      adapter.bloom        // glow behind the bars while playing
    property alias reflection: adapter.reflection   // mirrored band height, fraction of screen (0 = off)
    property alias idleWave:   adapter.idleWave      // breathing line while silent
    property alias style:      adapter.style       // bars | wave | dots
    property alias shape:      adapter.shape       // rounded | flat (bar/dot cap)
    property alias position:   adapter.position    // bottom | top | center
    property alias mirror:     adapter.mirror      // symmetric low->high->low band order

    // Persist the on/off so the Hub toggle and the Super+M keybind agree and it
    // survives a restart.
    function setEnabled(on) {
        adapter.enabled = on;
        file.writeAdapter();
    }

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/visualizer.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool enabled: true
            property int bars: 64
            property real height: 0.42
            property real thickness: 0.58
            property real bloom: 0.6
            property real reflection: 0.1
            property bool idleWave: true
            property string style: "bars"
            property string shape: "rounded"
            property string position: "bottom"
            property bool mirror: false
        }
    }

    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
