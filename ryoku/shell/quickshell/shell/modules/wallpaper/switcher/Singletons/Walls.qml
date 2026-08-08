pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper source for the switcher: runs index.sh (thumbnails + a dominant-hue
// reading for every image and video), buckets each entry by colour, and applies
// a pick through `ryoku-shell wallpaper set` so it shares the transition,
// palette and state path with the Super+W keybind. Entries come back sorted by
// colour, neutral last, so the grid reads as a rainbow before any filtering.
//
// entry = { type ("image"|"live"), path, name, mtime, thumb, hue, sat, group }.
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

    // absolute path of the wallpaper on screen, watched so a pick lights its cell
    // as soon as the daemon writes the state.
    readonly property string current: stateView.text().trim()
    FileView {
        id: stateView
        path: root.statePath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    function refresh() {
        if (indexProc.running)
            return;
        loading = true;
        indexProc.running = true;
    }

    Process {
        id: indexProc
        command: ["sh", root.script]
        stdout: StdioCollector {
            onStreamFinished: {
                var out = [];
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
                        group: Colors.bucket(hue, sat)
                    });
                }
                out.sort(function (a, b) {
                    var ga = a.group === Colors.neutral ? 100 : a.group;
                    var gb = b.group === Colors.neutral ? 100 : b.group;
                    if (ga !== gb)
                        return ga - gb;
                    return b.sat - a.sat;
                });
                root.entries = out;
                root.loading = false;
            }
        }
    }

    // apply the pick; a pick landing while one is in flight queues and replays on
    // exit, so rapid picks converge on the last one.
    property string queuedApply: ""
    function apply(path) {
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

    Component.onCompleted: refresh()
}
