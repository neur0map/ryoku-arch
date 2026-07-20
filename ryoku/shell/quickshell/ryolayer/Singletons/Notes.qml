pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Quick-note store for the layer's notes widget: a flat list of notes plus the
// last-viewed pointer, persisted in ~/.config/ryoku/notes.json, watched and
// atomic, the same contract as ryolayer.json via Config. One note is edited at
// a time (the widget is editor-first); `current` is the id of that note so a
// reload lands back where the user left off. This singleton is the only writer;
// a plain writeAdapter suffices as no exec reads the file back.
Singleton {
    id: root

    readonly property var notes: adapter.notes

    // bumps on every mutation; the widget's nav/stamp bindings key on it.
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
            // id is Date.now(): a double holds it exactly; a 32-bit int overflows.
            property double current: 0
            property var notes: []
        }
    }

    function save() {
        file.writeAdapter();
        root.rev++;
        root.changed();
    }

    function _index() {
        var n = adapter.notes || [];
        for (var i = 0; i < n.length; i++)
            if (n[i].id === adapter.current)
                return i;
        return n.length ? 0 : -1;
    }

    readonly property int index: (root.rev, _index())
    readonly property int count: (root.rev, (adapter.notes || []).length)
    readonly property var _cur: (root.rev, (_index() >= 0 ? adapter.notes[_index()] : null))
    readonly property double currentId: _cur ? _cur.id : -1
    readonly property string currentText: _cur ? _cur.text : ""
    readonly property double currentCreated: _cur ? _cur.created : 0

    function newNote() {
        var now = Date.now();
        var arr = (adapter.notes || []).slice();
        arr.unshift({ id: now, text: "", created: now });
        adapter.notes = arr;
        adapter.current = now;
        save();
    }

    // Save text to the note the editor buffer belongs to, addressed by id (not
    // the live `current`): navigating flushes the outgoing note's buffer, and a
    // debounced autosave must never land a stale buffer on a note the user has
    // since navigated to. A no-op when the note is gone or the text is unchanged.
    function saveNote(id, text) {
        var arr = (adapter.notes || []).slice();
        var i = -1;
        for (var k = 0; k < arr.length; k++)
            if (arr[k].id === id) { i = k; break; }
        if (i < 0 || arr[i].text === text)
            return;
        var e = JSON.parse(JSON.stringify(arr[i]));
        e.text = text;
        arr[i] = e;
        adapter.notes = arr;
        save();
    }

    function removeCurrent() {
        var arr = (adapter.notes || []).slice();
        var i = _index();
        if (i < 0) {
            newNote();
            return;
        }
        arr.splice(i, 1);
        if (arr.length === 0) {
            var now = Date.now();
            arr.push({ id: now, text: "", created: now });
            adapter.notes = arr;
            adapter.current = now;
            save();
            return;
        }
        var ni = Math.min(i, arr.length - 1);
        adapter.notes = arr;
        adapter.current = arr[ni].id;
        save();
    }

    function removeAll() {
        var now = Date.now();
        adapter.notes = [{ id: now, text: "", created: now }];
        adapter.current = now;
        save();
    }

    function next() {
        var n = adapter.notes || [];
        var i = _index();
        if (i >= 0 && i + 1 < n.length) {
            adapter.current = n[i + 1].id;
            save();
        }
    }

    function prev() {
        var n = adapter.notes || [];
        var i = _index();
        if (i > 0) {
            adapter.current = n[i - 1].id;
            save();
        }
    }

    // Seed one empty note on a genuine first run so the editor always has a
    // target; on an existing file (including a v1 file with no `current` key)
    // point current at the first note. Additive: no note is ever dropped.
    Component.onCompleted: {
        if (!file.text()) {
            var now = Date.now();
            adapter.notes = [{ id: now, text: "", created: now }];
            adapter.current = now;
            file.writeAdapter();
        } else {
            // v1/stale file: current absent or not pointing at a real note.
            // Pin it to the first note and persist the additive key.
            var n = adapter.notes || [];
            var found = false;
            for (var i = 0; i < n.length; i++)
                if (n[i].id === adapter.current) { found = true; break; }
            if (!found && n.length > 0) {
                adapter.current = n[0].id;
                file.writeAdapter();
            }
        }
    }
}
