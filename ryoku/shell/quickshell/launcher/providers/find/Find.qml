import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import ".."

// Scoped file finder, reached only by an explicit command so a plain search is
// never flooded with deep system paths:
//   /file <q>    files by name (home, junk excluded)
//   /folder <q>  directories
//   /image <q>   images in Pictures + Downloads (by extension)
//   /video <q>   videos in Videos + Downloads (by extension)
// Backed by fd, async + cached per (mode, query). Opens with xdg-open; a
// secondary action reveals the containing folder. Not a default provider.
Provider {
    id: find

    providerId: "find"
    defaultProvider: false
    prefixes: ["/file", "/folder", "/image", "/video"]

    property bool available: false
    property string cachedKey: ""
    property var cachedRows: []
    property string pendingMode: ""
    property string pendingQuery: ""

    readonly property string home: Quickshell.env("HOME") || "."

    function modeFor(prefix) {
        if (prefix === "/folder") return "folder";
        if (prefix === "/image") return "image";
        if (prefix === "/video") return "video";
        return "file";
    }

    // fd argv for a mode: type, extension filters, and the roots to search. No
    // --hidden, so dot-dirs (.cache, .claude, .config) are skipped; explicit
    // excludes drop the heavy non-dot dirs too.
    function fdArgs(mode, query) {
        var common = ["--max-results", "25", "--exclude", "node_modules",
            "--exclude", ".git", "--exclude", "Trash"];
        var imgExt = ["--extension", "png", "--extension", "jpg", "--extension", "jpeg",
            "--extension", "gif", "--extension", "webp", "--extension", "svg",
            "--extension", "bmp", "--extension", "avif"];
        var vidExt = ["--extension", "mp4", "--extension", "mkv", "--extension", "webm",
            "--extension", "mov", "--extension", "avi", "--extension", "m4v"];
        if (mode === "folder")
            return ["fd", "--type", "d"].concat(common).concat([query, find.home]);
        if (mode === "image")
            return ["fd", "--type", "f"].concat(imgExt).concat(common).concat([query, find.home + "/Pictures", find.home + "/Downloads"]);
        if (mode === "video")
            return ["fd", "--type", "f"].concat(vidExt).concat(common).concat([query, find.home + "/Videos", find.home + "/Downloads"]);
        return ["fd", "--type", "f"].concat(common).concat([query, find.home]);
    }

    function baseName(path) {
        var p = String(path);
        var i = p.lastIndexOf("/");
        return i >= 0 ? p.slice(i + 1) : p;
    }

    function shortPath(path) {
        return String(path).replace(find.home, "~");
    }

    // Section label per mode, so folder results read FOLDER, not FILE.
    function kindFor(mode) {
        if (mode === "folder") return "Folder";
        if (mode === "image") return "Image";
        if (mode === "video") return "Video";
        return "File";
    }

    function rowFor(rawPath, kind) {
        // fd prints directories with a trailing slash; strip it or the
        // basename comes out empty and the row renders with no title.
        var path = String(rawPath).replace(/\/+$/, "");
        return {
            id: "find:" + path,
            title: baseName(path),
            subtitle: shortPath(path.replace(/\/[^/]*$/, "")),
            icon: "",
            type: kind || "File",
            score: 0,
            actions: [
                { name: "Open", icon: "", execute: function () { Quickshell.execDetached(["xdg-open", path]); } },
                { name: "Reveal", icon: "", execute: function () { Quickshell.execDetached(["xdg-open", path.replace(/\/[^/]*$/, "")]); } }
            ]
        };
    }

    function query(text, prefix) {
        if (!find.available)
            return [];
        var mode = modeFor(prefix);
        var t = (text || "").trim();
        if (t.length < 1)
            return [];
        var key = mode + "\u0000" + t;
        if (key === find.cachedKey) {
            var kind = find.kindFor(mode);
            return find.cachedRows.map(function (p) { return find.rowFor(p, kind); });
        }
        find.pendingMode = mode;
        find.pendingQuery = t;
        debounce.restart();
        return [];
    }

    Timer {
        id: debounce
        interval: 130
        repeat: false
        onTriggered: {
            findProc.cacheKey = find.pendingMode + "\u0000" + find.pendingQuery;
            findProc.command = find.fdArgs(find.pendingMode, find.pendingQuery);
            findProc.running = false;
            findProc.running = true;
        }
    }

    Process {
        id: availProc
        command: ["sh", "-c", "command -v fd >/dev/null 2>&1"]
        onExited: (code) => { find.available = (code === 0); }
    }

    Process {
        id: findProc
        onRunningChanged: Dispatcher.setBusy("find", running)
        property string cacheKey: ""
        property var hits: []
        stdout: SplitParser {
            onRead: line => { if (line.trim().length) findProc.hits.push(line.trim()); }
        }
        onStarted: findProc.hits = []
        onExited: {
            find.cachedKey = findProc.cacheKey;
            find.cachedRows = findProc.hits.slice();
            Dispatcher.notifyAsync();
        }
    }

    Component.onCompleted: {
        availProc.running = true;
        Dispatcher.register(find);
    }
}
