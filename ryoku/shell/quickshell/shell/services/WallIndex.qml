pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "lib/WallColors.js" as WallColors

// Resident wallpaper index for the Super+W frame menu. index.sh reads one cached
// thumbnail and a dominant-hue value per image and video (~0.4s warm), which is
// too slow to sit on the menu-open hot path: the frame menu used to run it fresh
// on every open, so the theme cards (instant solid colours) painted a beat before
// the wallpaper tiles arrived and the belts glitched as thumbnails popped in.
//
// This singleton runs the pass once at daemon start and caches the result, so the
// menu opens with its tiles already in hand. A menu open still kicks a background
// refresh to pick up wallpapers added since, but the entries only reassign when
// the set actually changed, so a reopen never churns the belts.
//
// entry = { type ("image"|"live"), mtime, path, name, thumb, preview, hue, sat, group }.
Singleton {
    id: root

    property var entries: []
    readonly property int count: entries.length
    property bool loading: false

    // index.sh path = RYOKU_SHELL_DIR in dev, else the installed quickshell tree
    // (the plugins idiom; reliable under both `qs -p` and `qs -c`).
    readonly property string shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string script: (shellDir && shellDir.length > 0)
        ? shellDir + "/quickshell/shell/modules/wallpaper/switcher/index.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/shell/modules/wallpaper/switcher/index.sh"
    readonly property string statePath: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku-wallpaper"

    // the wallpaper on screen (on-air dot), watched so a pick lights its tile as
    // soon as the daemon writes the state.
    readonly property string current: stateView.text().trim()
    FileView {
        id: stateView
        path: root.statePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    // signature of the last emitted set (paths, in index order), so a background
    // refresh that finds the same wallpapers leaves `entries` -- and the belts
    // bound to it -- untouched instead of rebuilding every tile.
    property string sig: ""

    function refresh() {
        if (indexProc.running)
            return;
        root.loading = true;
        indexProc.running = true;
    }

    Process {
        id: indexProc
        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
                var sig = "";
                var lines = this.text.split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var p = lines[i].split("\t");
                    if (p.length < 6)
                        continue;
                    var hue = parseFloat(p[4]) || 0;
                    var sat = parseFloat(p[5]) || 0;
                    var path = p[2];
                    out.push({
                        type: p[0],
                        mtime: parseFloat(p[1]) || 0,
                        path: path,
                        name: path.substring(path.lastIndexOf("/") + 1),
                        thumb: p[3],
                        preview: p.length > 6 ? p[6] : "",
                        hue: hue,
                        sat: sat,
                        group: WallColors.bucket(hue, sat)
                    });
                    sig += path + "\n";
                }
                root.loading = false;
                if (sig === root.sig)
                    return;
                out.sort(function (a, b) {
                    var ga = a.group === 99 ? 100 : a.group;
                    var gb = b.group === 99 ? 100 : b.group;
                    if (ga !== gb)
                        return ga - gb;
                    return b.sat - a.sat;
                });
                root.sig = sig;
                root.entries = out;
            }
        }
    }

    // apply the pick; a pick landing while one is in flight queues and replays on
    // exit, so rapid picks converge on the last one.
    property string queuedApply: ""
    function apply(path) {
        if (!path || path.length === 0)
            return;
        if (applyProc.running) {
            queuedApply = path;
            return;
        }
        applyProc.command = ["ryoku-shell", "wallpaper", "set", path];
        applyProc.running = true;
    }
    Process {
        id: applyProc
        onExited: {
            if (root.queuedApply.length) {
                var next = root.queuedApply;
                root.queuedApply = "";
                applyProc.command = ["ryoku-shell", "wallpaper", "set", next];
                applyProc.running = true;
            }
        }
    }
}
