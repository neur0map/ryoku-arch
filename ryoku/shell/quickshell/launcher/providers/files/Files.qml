import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import ".."

// File search backed by fd. Default-ranked below apps and gated to queries of 3+
// chars so a short app search never forks fd. Async + cached: query() returns the
// cached hits for the current text and starts a fresh fd run (debounced) on
// change, repainting via Dispatcher.notifyAsync. Opens with xdg-open; a secondary
// action reveals the file in the manager.
Provider {
    id: files

    providerId: "files"

    property bool available: false
    property string cachedQuery: ""
    property var cachedRows: []
    property string pendingQuery: ""

    readonly property string home: Quickshell.env("HOME") || "."

    function baseName(path) {
        var p = String(path);
        var i = p.lastIndexOf("/");
        return i >= 0 ? p.slice(i + 1) : p;
    }

    function rowFor(path) {
        return {
            id: "file:" + path,
            title: baseName(path),
            subtitle: path,
            icon: "",
            type: "File",
            score: 60,
            actions: [
                { name: "Open", icon: "", execute: function () { Quickshell.execDetached(["xdg-open", path]); } },
                { name: "Reveal", icon: "", execute: function () { Quickshell.execDetached(["xdg-open", path.replace(/\/[^/]*$/, "")]); } }
            ]
        };
    }

    function query(text) {
        if (!files.available)
            return [];
        var t = (text || "").trim();
        if (t.length < 3)
            return [];
        if (t === files.cachedQuery)
            return files.cachedRows.map(files.rowFor);
        files.pendingQuery = t;
        debounce.restart();
        return [];
    }

    Timer {
        id: debounce
        interval: 140
        repeat: false
        onTriggered: {
            findProc.term = files.pendingQuery;
            findProc.running = false;
            findProc.running = true;
        }
    }

    Process {
        id: availProc
        command: ["sh", "-c", "command -v fd >/dev/null 2>&1"]
        onExited: (code) => { files.available = (code === 0); }
    }

    Process {
        id: findProc
        property string term: ""
        property var hits: []
        command: ["fd", "--type", "f", "--hidden", "--exclude", ".git", "--max-results", "20", term, files.home]
        stdout: SplitParser {
            onRead: line => { if (line.trim().length) findProc.hits.push(line.trim()); }
        }
        onStarted: findProc.hits = []
        onExited: {
            files.cachedQuery = findProc.term;
            files.cachedRows = findProc.hits.slice();
            Dispatcher.notifyAsync();
        }
    }

    Component.onCompleted: {
        availProc.running = true;
        Dispatcher.register(files);
    }
}
