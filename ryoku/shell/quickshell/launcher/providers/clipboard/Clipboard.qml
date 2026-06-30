import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import "../../lib/fuzzy.js" as Fuzzy
import ".."

// Clipboard-history provider on the ";" prefix. Unlike the pill's always-on
// cliphist watcher (which the launcher must not duplicate, to keep the inactive
// footprint down), this loads `cliphist list` on demand while the user searches,
// refreshing at most every couple of seconds. Copy decodes the entry back to the
// clipboard; a secondary action deletes it.
Provider {
    id: clipboard

    providerId: "clipboard"
    prefix: ";"
    defaultProvider: false

    property var entries: []
    property double loadedAt: 0
    readonly property int staleMs: 2000

    function isImage(preview) {
        return /^\[\[ binary data .*(png|jpe?g|gif|bmp|webp).* \]\]$/.test(preview);
    }

    function rowFor(entry) {
        var img = isImage(entry.preview);
        return {
            id: "clip:" + entry.id,
            title: img ? "[image] " + entry.preview.replace(/^\[\[ binary data /, "").replace(/ \]\]$/, "") : entry.preview,
            subtitle: "Clipboard",
            icon: "",
            type: "Clipboard",
            score: 0,
            actions: [
                { name: "Copy", icon: "", execute: function () {
                    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", String(entry.id)]);
                } },
                { name: "Delete", icon: "", execute: function () {
                    Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist delete", "_", String(entry.id)]);
                } }
            ]
        };
    }

    function query(text) {
        var now = Date.now();
        if (clipboard.entries.length === 0 || now - clipboard.loadedAt > clipboard.staleMs) {
            if (!listProc.running) {
                listProc.running = false;
                listProc.running = true;
            }
        }
        var q = (text || "").trim().toLowerCase();
        var rows = [];
        for (var i = 0; i < clipboard.entries.length; i++) {
            var e = clipboard.entries[i];
            if (q.length === 0 || e.preview.toLowerCase().indexOf(q) !== -1)
                rows.push(rowFor(e));
        }
        return rows;
    }

    Process {
        id: listProc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var out = [];
                for (var i = 0; i < lines.length; i++) {
                    var tab = lines[i].indexOf("\t");
                    if (tab < 1)
                        continue;
                    var id = lines[i].substring(0, tab);
                    if (!/^\d+$/.test(id))
                        continue;
                    out.push({ id: id, preview: lines[i].substring(tab + 1) });
                }
                clipboard.entries = out;
                clipboard.loadedAt = Date.now();
                Dispatcher.notifyAsync();
            }
        }
    }

    Component.onCompleted: Dispatcher.register(clipboard);
}
