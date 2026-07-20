pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Quick-note store for the layer's notes widget: a flat list of jots persisted
// in ~/.config/ryoku/notes.json, watched and atomic, the same contract as
// ryolayer.json via Config. Newest first in the array (prepend on add). This
// singleton is the only writer; a plain writeAdapter suffices as no exec reads
// the file back.
Singleton {
    id: root

    readonly property var notes: adapter.notes

    // bumps on every mutation; list consumers key their model on it.
    property int rev: 0
    signal changed()

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/notes.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: { reload(); root.rev++; root.changed(); }

        JsonAdapter {
            id: adapter
            property var notes: []
        }
    }

    function save() {
        file.writeAdapter();
        root.rev++;
        root.changed();
    }

    function add(text) {
        var t = (text || "").trim();
        if (!t)
            return;
        var now = Date.now();
        var arr = (adapter.notes || []).slice();
        arr.unshift({ id: now, text: t, created: now });
        adapter.notes = arr;
        save();
    }

    function remove(id) {
        adapter.notes = (adapter.notes || []).filter(function (n) { return n.id !== id; });
        save();
    }

    // seed only on a genuine first run, never over a present file.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
