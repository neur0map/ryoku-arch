pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * ~/Downloads/Stash: the download landing plus the compress/install backends.
 * A live FolderListModel tracks the folder (created on first load); cobalt
 * drives a one-at-a-time download queue through stash-cobalt.sh. compressPick /
 * installPick open a multi-file picker and run the helper on the selection.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: home + "/Downloads/Stash"
    readonly property string scriptDir: home + "/.config/hypr/scripts"
    readonly property string cobaltScript: scriptDir + "/stash-cobalt.sh"

    readonly property alias files: files
    readonly property int count: files.count
    readonly property alias queueModel: queueModel

    // Newest-first, capped: the Tools "recently downloaded" list. Sorted here in
    // JS because FolderListModel's own time sort is unreliable across builds.
    readonly property var recentFiles: {
        const arr = [];
        const n = files.count;
        for (let i = 0; i < n; i++)
            arr.push({ name: files.get(i, "fileName"),
                       path: files.get(i, "filePath"),
                       t: files.get(i, "fileModified") });
        arr.sort((a, b) => b.t - a.t);
        return arr.slice(0, 6);
    }

    // Cobalt download queue.
    property string dlMode: "auto"        // auto | audio | mute
    property int activeJob: -1            // index of the running queue entry, -1 idle
    property var supportedSites: []       // cobalt's supported services (for the Tools bubble)

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function removeFile(path) {
        Quickshell.execDetached(["rm", "-f", path]);
    }

    function clearAll() {
        Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/*", "--", root.dir]);
    }

    // ── Compress / install ──────────────────────────────────────────────
    // Run the helpers on an explicit set of files chosen in the in-shell picker
    // (PanelPicker); the launcher entries deep-link to the same picker.
    function compress(paths) {
        if (!paths || paths.length === 0) return;
        Quickshell.execDetached(["bash", root.scriptDir + "/stash-compress.sh"].concat(paths));
    }
    function install(paths) {
        if (!paths || paths.length === 0) return;
        Quickshell.execDetached(["bash", root.scriptDir + "/stash-install.sh"].concat(paths));
    }

    // ── Cobalt download + remux ─────────────────────────────────────────
    function enqueueDownload(url, mode) {
        var u = ("" + url).trim();
        if (u.length === 0)
            return;
        queueModel.append({ kind: "download", arg: u, mode: mode || root.dlMode,
            name: "link", state: "queued", pct: 0, msg: "" });
        pumpQueue();
    }

    function enqueueRemux(file) {
        queueModel.append({ kind: "remux", arg: file, mode: "",
            name: ("" + file).split("/").pop(), state: "queued", pct: 0, msg: "" });
        pumpQueue();
    }

    // One worker at a time walks the queue, so a burst of links downloads in
    // order instead of fighting over the network.
    function pumpQueue() {
        if (root.activeJob >= 0)
            return;
        for (var i = 0; i < queueModel.count; i++) {
            if (queueModel.get(i).state === "queued") {
                root.activeJob = i;
                queueModel.setProperty(i, "state", "running");
                var e = queueModel.get(i);
                workerProc.command = e.kind === "remux"
                    ? ["bash", root.cobaltScript, "remux", e.arg]
                    : ["bash", root.cobaltScript, "download", e.arg, e.mode];
                workerProc.running = true;
                return;
            }
        }
    }

    function onWorkerLine(line) {
        if (root.activeJob < 0)
            return;
        var i = root.activeJob;
        var t = ("" + line).split("\t");
        if (t[0] === "START") {
            if (t[1]) queueModel.setProperty(i, "name", t[1]);
        } else if (t[0] === "PROGRESS") {
            queueModel.setProperty(i, "pct", parseInt(t[1]) || 0);
        } else if (t[0] === "SAVED") {
            if (t[1]) queueModel.setProperty(i, "name", t[1]);
            queueModel.setProperty(i, "state", "done");
        } else if (t[0] === "ERROR") {
            queueModel.setProperty(i, "msg", t[1] || "failed");
            queueModel.setProperty(i, "state", "error");
        }
    }

    function clearQueueDone() {
        for (var i = queueModel.count - 1; i >= 0; i--) {
            var s = queueModel.get(i).state;
            if (s === "done" || s === "error")
                queueModel.remove(i);
        }
    }

    FolderListModel {
        id: files
        folder: "file://" + root.dir
        showDirs: false
        showHidden: false
        nameFilters: ["*"]
    }

    ListModel {
        id: queueModel
    }

    Process {
        id: workerProc
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.onWorkerLine(line)
        }
        onExited: (code) => {
            if (root.activeJob >= 0) {
                var st = queueModel.get(root.activeJob).state;
                if (st === "running")
                    queueModel.setProperty(root.activeJob, "state", code === 0 ? "done" : "error");
            }
            root.activeJob = -1;
            root.pumpQueue();
        }
    }

    // Cobalt's supported services, for the Tools "works with" bubble. Live from
    // the instance when it's up, else the script's built-in list.
    Process {
        id: sitesProc
        command: ["bash", root.cobaltScript, "sites"]
        stdout: StdioCollector {
            id: sitesOut
            onStreamFinished: {
                const out = ("" + sitesOut.text).trim();
                root.supportedSites = out.length > 0 ? out.split("\n").filter(l => l.length > 0) : [];
            }
        }
    }

    Component.onCompleted: {
        Quickshell.execDetached(["mkdir", "-p", root.dir]);
        sitesProc.running = true;
    }
}
