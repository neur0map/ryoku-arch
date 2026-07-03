import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import "gpk.js" as Gpk
import ".."

// Package provider backed by GPK (`gpk search --json`), which spans every package
// manager gpk wraps. Routed by "/" is the actions panel; packages use explicit
// "install "/"remove "/"search " queries (matching inir) so a plain search never
// forks gpk. Search is async + cached; installs/removes spawn a terminal because
// gpk needs a tty for the privilege prompt (see gpk-launcher-backend-notes).
Provider {
    id: packages

    providerId: "packages"
    prefix: ">"
    defaultProvider: false

    property bool available: false
    property string cachedQuery: ""
    property var cachedRows: []
    property string pendingQuery: ""

    readonly property string terminal: "kitty"

    // text after ">": "search x" / "install x" / "remove x", or a bare query that
    // defaults to search. So ">yay" searches, ">install yay" installs.
    function parseOp(text) {
        var m = String(text || "").match(/^(install|remove|search)\s+(.+)$/i);
        if (m)
            return { op: m[1].toLowerCase(), term: m[2].trim() };
        var t = String(text || "").trim();
        return t.length ? { op: "search", term: t } : null;
    }

    function rowFor(pkg, op) {
        var verb = op === "remove" ? "Remove" : (pkg.installed ? "Reinstall" : "Install");
        return {
            id: "pkg:" + pkg.source + ":" + pkg.name,
            title: pkg.name + "  " + pkg.version,
            subtitle: pkg.source + (pkg.installed ? "  (installed)" : "") + "  " + pkg.description,
            icon: "",
            type: "Package",
            score: 0,
            actions: [{
                name: verb,
                icon: "",
                execute: function () {
                    var gpkOp = op === "remove" ? "remove" : "install";
                    Quickshell.execDetached([packages.terminal, "-e", "gpk", gpkOp, pkg.name]);
                }
            }]
        };
    }

    function query(text) {
        if (!packages.available)
            return [];
        var p = parseOp(text);
        if (!p || p.term.length < 2)
            return [];
        if (p.term === packages.cachedQuery)
            return packages.cachedRows.map(function (pkg) { return packages.rowFor(pkg, p.op); });
        packages.pendingQuery = p.term;
        debounce.restart();
        return [];
    }

    Timer {
        id: debounce
        interval: 120
        repeat: false
        onTriggered: {
            packages.fullFor = "";
            searchProc.term = packages.pendingQuery;
            searchProc.running = false;
            searchProc.running = true;
            fastProc.term = packages.pendingQuery;
            fastProc.running = false;
            fastProc.running = true;
        }
    }

    // Fast lane: pacman/aur answer from gpk's scan cache in well under a
    // second, while the full sweep hits live registries (npm, cargo, pip...)
    // and can take tens of seconds. Local rows show immediately; the full
    // set replaces them when it lands. fullFor marks a term the full sweep
    // has already answered so a slow fast-lane result never regresses it.
    property string fullFor: ""

    Process {
        id: fastProc
        property string term: ""
        property string out: ""
        command: ["gpk", "search", term, "--json", "--limit", "30", "--manager", "pacman,aur"]
        stdout: SplitParser {
            onRead: data => fastProc.out += data + "\n"
        }
        onStarted: fastProc.out = ""
        onExited: (code, status) => {
            // gpk: 0 = results, 2 = clean no-results, 1 = error.
            if (status !== 0 || code === 1)
                return;
            if (packages.fullFor === fastProc.term)
                return;
            packages.cachedQuery = fastProc.term;
            packages.cachedRows = Gpk.parse(fastProc.out);
            Dispatcher.notifyAsync();
        }
    }

    Process {
        id: availProc
        command: ["gpk", "search", "--help"]
        onExited: (code) => { packages.available = (code === 0); }
    }

    Process {
        id: searchProc
        onRunningChanged: Dispatcher.setBusy("packages", running)
        property string term: ""
        property string out: ""
        command: ["gpk", "search", term, "--json", "--limit", "30"]
        stdout: SplitParser {
            onRead: data => searchProc.out += data + "\n"
        }
        onStarted: searchProc.out = ""
        onExited: (code, status) => {
            // killed = superseded; exit 1 = gpk failure. Cache neither, so a
            // transient failure does not pin stale rows to a term. Exit 2 is
            // a clean no-results run and caches like a hit.
            if (status !== 0 || code === 1)
                return;
            packages.fullFor = searchProc.term;
            packages.cachedQuery = searchProc.term;
            packages.cachedRows = Gpk.parse(searchProc.out);
            Dispatcher.notifyAsync();
        }
    }

    Component.onCompleted: {
        availProc.running = true;
        Dispatcher.register(packages);
    }
}
