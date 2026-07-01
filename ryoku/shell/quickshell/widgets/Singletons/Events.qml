pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../calendar/lib/events.js" as Model

// Local calendar events for the desktop calendar widget, the SAME store the
// pill's calendar reads and writes: a plain JSON array at
// ~/.local/state/ryoku/events.json. That shared file is the only link between
// the two surfaces (they are separate quickshell processes, no IPC), so a note
// left on a day here shows up in the pill and vice versa.
//
// The file IS watched here: the widget stays on the wallpaper, so it must pick
// up an edit made in the pill without a restart. atomicWrites means our own
// setText lands as a rename, and reloadEvents runs on the resulting onLoaded
// (after the buffer refreshes), so re-reading our own write is idempotent, not
// a stale read. All logic lives in calendar/lib/events.js (node-tested); this
// singleton is the thin persistence + reactive `events` wrapper.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku"

    property var events: []
    property int nextId: 1

    function reloadEvents() {
        var arr = Model.parse(file.text());
        root.nextId = Model.nextIdFrom(arr);
        root.events = arr;
    }

    function persist() {
        file.setText(JSON.stringify(root.events));
    }

    function forDate(dateStr) { return Model.forDate(root.events, dateStr); }
    function hasEvents(dateStr) { return Model.hasEvents(root.events, dateStr); }

    function add(date, endDate, time, endTime, text) {
        root.events = Model.add(root.events, root.nextId, {
            date: date, endDate: endDate, time: time, endTime: endTime, text: text
        });
        root.nextId += 1;
        root.persist();
    }

    // Add from one typed line, splitting an optional leading HH:MM start time.
    // Returns false (and adds nothing) when the line has no text.
    function addEntry(date, raw) {
        var p = Model.parseEntry(raw);
        if (p.text.length === 0)
            return false;
        root.add(date, "", p.time, "", p.text);
        return true;
    }

    function remove(id) {
        root.events = Model.remove(root.events, id);
        root.persist();
    }

    // The state dir may not exist on a fresh profile; create it before the first
    // persist so setText doesn't fail silently into a dropped event.
    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    FileView {
        id: file
        path: root.stateDir + "/events.json"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.reloadEvents()
        onLoadFailed: root.reloadEvents()
    }
}
