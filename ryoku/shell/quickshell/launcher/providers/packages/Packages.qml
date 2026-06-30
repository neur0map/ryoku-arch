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
    defaultProvider: true

    property bool available: false
    property string cachedQuery: ""
    property var cachedRows: []
    property string pendingQuery: ""

    readonly property string terminal: "kitty"

    function parsePrefixed(text) {
        var m = String(text || "").match(/^(install|remove|search)\s+(.+)$/i);
        if (!m)
            return null;
        return { op: m[1].toLowerCase(), term: m[2].trim() };
    }

    function rowFor(pkg, op) {
        var verb = op === "remove" ? "Remove" : (pkg.installed ? "Reinstall" : "Install");
        return {
            id: "pkg:" + pkg.source + ":" + pkg.name,
            title: pkg.name + "  " + pkg.version,
            subtitle: pkg.source + (pkg.installed ? "  (installed)" : "") + "  " + pkg.description,
            icon: "",
            type: "Package",
            score: 30,
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
        var p = parsePrefixed(text);
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
            searchProc.term = packages.pendingQuery;
            searchProc.running = false;
            searchProc.running = true;
        }
    }

    Process {
        id: availProc
        command: ["gpk", "search", "--help"]
        onExited: (code) => { packages.available = (code === 0); }
    }

    Process {
        id: searchProc
        property string term: ""
        property string out: ""
        command: ["gpk", "search", term, "--json", "--limit", "30"]
        stdout: SplitParser {
            onRead: data => searchProc.out += data + "\n"
        }
        onStarted: searchProc.out = ""
        onExited: {
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
