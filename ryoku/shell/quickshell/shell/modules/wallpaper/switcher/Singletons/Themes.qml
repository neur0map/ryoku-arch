pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Colour-scheme source for the switcher's Color-scheme belt, the theme twin of
// Walls. The catalog (the two dynamic variants plus the 57 static themes) is
// served by the daemon from its authoritative palettes, so QML keeps no copy:
// `ryoku-shell theme catalog` prints it and this parses it once per open. The
// active scheme is read from shell.json (the daemon is its sole writer) so the
// on-air badge and the follow toggle track real state; apply() writes it back
// through `ryoku-shell theme <id>`, the seam the sidebar picker also uses.
//
// card = { id, label, dynamic, icon, dark, sw:[surface, onSurface, primary,
//          secondary, tertiary, error, outline] }.
Singleton {
    id: root

    property var entries: []                                  // full catalog (dynamic first)
    readonly property var themes: entries.filter(e => !e.dynamic)  // static only, for the belt
    property bool loading: false

    // the applied scheme id (shell.json theme.theme), file-driven but set
    // optimistically on a pick so the badge tracks immediately.
    readonly property string fileActive: {
        try {
            var doc = JSON.parse(shellView.text());
            return (doc && doc.theme && typeof doc.theme.theme === "string") ? doc.theme.theme : "";
        } catch (e) {
            return "";
        }
    }
    property string active: fileActive
    onFileActiveChanged: root.active = root.fileActive

    // dynamic (follows the wallpaper palette) == the two dynamic variants and an
    // absent key; mirrors the daemon's staticName rule so the toggle needs no
    // round trip.
    readonly property bool following: root.active === "" || root.active === "Default" || root.active === "Wallpaper"

    function refresh() {
        if (catalogProc.running)
            return;
        loading = true;
        catalogProc.running = true;
    }

    Process {
        id: catalogProc
        command: ["ryoku-shell", "theme", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.entries = JSON.parse(this.text);
                } catch (e) {
                    root.entries = [];
                }
                root.loading = false;
            }
        }
    }

    FileView {
        id: shellView
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // apply a scheme; a pick landing while one is in flight queues and replays on
    // exit, so rapid picks converge on the last (mirrors Walls.apply).
    property string queued: ""
    function apply(id) {
        if (!id || id.length === 0)
            return;
        root.active = id;
        if (applyProc.running) {
            root.queued = id;
            return;
        }
        applyProc.command = ["ryoku-shell", "theme", id];
        applyProc.running = true;
    }
    Process {
        id: applyProc
        onExited: {
            if (root.queued.length) {
                var next = root.queued;
                root.queued = "";
                applyProc.command = ["ryoku-shell", "theme", next];
                applyProc.running = true;
            }
        }
    }

    Component.onCompleted: refresh()
}
