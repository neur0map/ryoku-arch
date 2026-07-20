pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The equalizer state: ten band gains and the enabled flag, persisted in
// ~/.config/ryoku/eq.json (this singleton is the only writer; ryoku-eq reads
// it at login and on apply). Live drags stream to the running chain over
// `ryoku-eq set`, throttled so a fader sweep is one process every 50ms, and
// the json write lands once on release via save().
Singleton {
    id: root

    readonly property var bandHz: ["31", "62", "125", "250", "500", "1K", "2K", "4K", "8K", "16K"]
    readonly property var presets: ({
        flat:   [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        bass:   [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
        vocal:  [-2, -1, 0, 1, 3, 4, 3, 1, 0, -1],
        bright: [0, 0, 0, 0, 0, 1, 2, 3, 4, 5]
    })

    property alias enabled: adapter.enabled
    property alias preset: adapter.preset
    readonly property var gains: adapter.gains

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/eq.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        JsonAdapter {
            id: adapter
            property bool enabled: false
            property string preset: "flat"
            property var gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        }
    }

    function save() { file.writeAdapter(); }

    function setEnabled(on) {
        adapter.enabled = on;
        save();
        Quickshell.execDetached(["ryoku-eq", "apply"]);
    }

    // live path: remember the latest value per band, flush on a short clock.
    property var _pendingBand: -1
    property real _pendingDb: 0
    Timer {
        id: flush
        interval: 50
        onTriggered: {
            if (root._pendingBand < 0)
                return;
            Quickshell.execDetached(["ryoku-eq", "set", String(root._pendingBand + 1), root._pendingDb.toFixed(1)]);
            root._pendingBand = -1;
        }
    }

    function setBand(i, db) {
        db = Math.max(-12, Math.min(12, db));
        var g = (adapter.gains || []).slice();
        while (g.length < 10)
            g.push(0);
        g[i] = Math.round(db * 10) / 10;
        adapter.gains = g;
        adapter.preset = "custom";
        if (root.enabled) {
            root._pendingBand = i;
            root._pendingDb = g[i];
            if (!flush.running)
                flush.start();
        }
    }

    function applyPreset(name) {
        var p = presets[name];
        if (!p)
            return;
        adapter.gains = p.slice();
        adapter.preset = name;
        save();
        if (root.enabled)
            for (var i = 0; i < 10; i++)
                Quickshell.execDetached(["ryoku-eq", "set", String(i + 1), p[i].toFixed(1)]);
    }
}
