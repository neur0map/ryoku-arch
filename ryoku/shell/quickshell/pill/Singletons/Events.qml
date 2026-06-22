pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../lib/events.js" as Model

/**
 * Local calendar events, persisted as a plain JSON array at
 * ~/.local/state/ryoku/events.json. The in-memory `events` is the source of
 * truth: add/remove mutate it and write the file, which is read back only at
 * startup. The file is deliberately NOT watched, because re-reading our own write
 * races the FileView's cached text and drops the just-added event. All logic
 * lives in lib/events.js so the model is unit-tested under node; this singleton
 * is the thin Quickshell wrapper (persistence + reactive `events`).
 */
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

    /** Add from one typed line, splitting an optional leading HH:MM start time.
     *  Returns false (and adds nothing) when the line has no text. */
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
    // persist so setText never fails silently into a dropped event.
    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }

    Component.onCompleted: reloadEvents()

    FileView {
        id: file
        path: root.stateDir + "/events.json"
        blockLoading: true
        printErrors: false
    }
}
