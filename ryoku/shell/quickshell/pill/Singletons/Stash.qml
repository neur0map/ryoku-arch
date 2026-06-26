pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * File stash bridge: a live snapshot of ~/Downloads/Stash and the back-end for
 * the stash surface. The FolderListModel watches the directory (created on first
 * load) so the grid stays current without polling; openFile, removeFile, clearAll
 * and addUrl drive it through detached coreutils. `hasMedia` / `hasInstallable`
 * read the live file types so the action bar only lights the actions that apply.
 *
 * Flows, all behind helper scripts under ~/.config/hypr/scripts:
 *  - LocalSend send. openSendPicker / openSendAll / openSendText kick a ~2s LAN
 *    discovery (lsState scanning|ready|sending); sendTo uploads the picked file,
 *    the whole stash, or a typed note to the chosen IP.
 *  - LocalSend receive. start/stopReceive run localsend.sh receive, a server that
 *    announces us on the LAN and drops incoming files into the stash.
 *  - Install / compress. requestInstall/Compress raise a confirm (taskState
 *    confirm); confirmTask runs the helper (running -> done|error).
 *  - Cobalt download + remux. openDownload raises the cobalt window; enqueue*
 *    feed a sequential processing queue driven by stash-cobalt.sh (a cobalt API
 *    client with a yt-dlp fallback; remux is a local lossless ffmpeg copy).
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: home + "/Downloads/Stash"
    readonly property string script: home + "/.config/hypr/scripts/localsend.sh"
    readonly property string scriptDir: home + "/.config/hypr/scripts"
    readonly property string cobaltScript: scriptDir + "/stash-cobalt.sh"

    readonly property alias files: files
    readonly property int count: files.count
    readonly property alias deviceModel: deviceModel
    readonly property alias queueModel: queueModel

    // Live file-type read so the action bar lights only what applies.
    readonly property bool hasMedia: {
        var n = files.count;
        for (var i = 0; i < n; i++) {
            // FolderListModel.fileSuffix is the COMPLETE suffix (after the first
            // dot), so a name like "clip.16.45.mp4" yields "16.45.mp4". Take the
            // real extension from the last dot instead.
            var nm = ("" + files.get(i, "fileName")).toLowerCase();
            var e = nm.substring(nm.lastIndexOf(".") + 1);
            if (/^(mp4|mkv|webm|mov|avi|m4v|mp3|flac|wav|ogg|opus|m4a|aac|png|jpe?g|webp|gif|bmp|tif|tiff)$/.test(e))
                return true;
        }
        return false;
    }
    readonly property bool hasInstallable: {
        var n = files.count;
        for (var i = 0; i < n; i++) {
            var nm = ("" + files.get(i, "fileName")).toLowerCase();
            // Everything stash-install.sh can install: AppImages, self-contained
            // tarballs, Arch packages (.pkg.tar.zst), Flatpak bundles, and .deb/.rpm
            // (payload extracted, best-effort). Self-extracting .bin/.run stay out:
            // running an arbitrary installer blind is unsafe.
            if (/\.(appimage|flatpak|deb|rpm|tar\.gz|tgz|tar\.xz|tar\.bz2|tar\.zst|tar)$/.test(nm))
                return true;
        }
        return false;
    }

    // Send flow.
    property string lsState: "idle"       // idle | scanning | ready | sending
    property string sendKind: "file"      // file | all | text
    property string pendingFile: ""
    property string composeText: ""

    // Receive flow.
    property string recvState: "idle"     // idle | listening
    property string recvAlias: ""
    property int recvCount: 0
    property string recvLast: ""

    // Install / compress.
    property string task: ""              // "" | install | compress
    property string taskState: "idle"     // idle | confirm | running | done | error
    property string taskMsg: ""

    // Emitted when an install reaches a privileged (sudo/polkit) step so the shell
    // can step the control deck aside and let the prompt take keyboard focus.
    signal authStepAside()

    // Cobalt download window.
    property bool dlOpen: false
    property string dlTab: "download"     // download | remux
    property string dlMode: "auto"        // auto | audio | mute
    property string dlText: ""
    property int activeJob: -1            // index of the running queue entry, -1 idle

    function openFile(path) {
        Quickshell.execDetached(["xdg-open", path]);
    }

    function removeFile(path) {
        Quickshell.execDetached(["rm", "-f", path]);
    }

    function clearAll() {
        Quickshell.execDetached(["sh", "-c", "rm -f \"$1\"/*", "--", root.dir]);
    }

    function addUrl(url) {
        var p = ("" + url).replace(/^file:\/\//, "");
        Quickshell.execDetached(["cp", "-n", p, root.dir]);
    }

    // ── Send ────────────────────────────────────────────────────────────
    function startScan() {
        deviceModel.clear();
        root.lsState = "scanning";
        discoverProc.running = true;
    }

    function rescan() {
        if (root.lsState !== "idle" && root.lsState !== "sending")
            startScan();
    }

    function openSendPicker(file) {
        root.sendKind = "file";
        root.pendingFile = file;
        startScan();
    }

    function openSendAll() {
        if (root.count === 0)
            return;
        root.sendKind = "all";
        root.pendingFile = "";
        startScan();
    }

    function openSendText() {
        root.sendKind = "text";
        root.pendingFile = "";
        root.composeText = "";
        startScan();
    }

    function cancelSend() {
        discoverProc.running = false;
        root.lsState = "idle";
        root.pendingFile = "";
        root.composeText = "";
    }

    function pasteCompose() {
        pasteProc.running = true;
    }

    function sendTo(ip) {
        root.lsState = "sending";
        if (root.sendKind === "all")
            sendProc.command = ["bash", root.script, "send-all", root.dir, ip];
        else if (root.sendKind === "text")
            // Notes have no file: drop the text into a temp file named note.txt so
            // the receiver shows a sensible name, send it, then clean up.
            sendProc.command = ["bash", "-c",
                "d=$(mktemp -d) && printf '%s' \"$1\" > \"$d/note.txt\" && bash \"$2\" send \"$d/note.txt\" \"$3\"; r=$?; rm -rf \"$d\"; exit $r",
                "--", root.composeText, root.script, ip];
        else
            sendProc.command = ["bash", root.script, "send", root.pendingFile, ip];
        sendProc.running = true;
    }

    // ── Receive ─────────────────────────────────────────────────────────
    function startReceive() {
        root.recvCount = 0;
        root.recvLast = "";
        root.recvAlias = "Ryoku Stash";
        root.recvState = "listening";
        recvProc.running = true;
    }

    function stopReceive() {
        recvProc.running = false;
        root.recvState = "idle";
    }

    function onRecvLine(line) {
        var t = ("" + line).split("\t");
        if (t[0] === "READY") {
            root.recvAlias = t[1] || "Ryoku Stash";
            root.recvState = "listening";
        } else if (t[0] === "INCOMING") {
            root.recvLast = t[1] || "";
        } else if (t[0] === "SAVED") {
            root.recvCount += 1;
            root.recvLast = t[1] || "";
        } else if (t[0] === "ERROR") {
            root.recvState = "idle";
        }
    }

    // ── Install / compress ──────────────────────────────────────────────
    function requestInstall() {
        if (root.hasInstallable) {
            root.task = "install";
            root.taskMsg = "";
            root.taskState = "confirm";
        }
    }

    function requestCompress() {
        if (root.hasMedia) {
            root.task = "compress";
            root.taskMsg = "";
            root.taskState = "confirm";
        }
    }

    function confirmTask() {
        if (root.task === "install")
            runTask("install", ["bash", root.scriptDir + "/stash-install.sh"]);
        else if (root.task === "compress")
            runTask("compress", ["bash", root.scriptDir + "/stash-compress.sh"]);
    }

    function runTask(name, cmd) {
        root.task = name;
        root.taskMsg = "";
        root.taskState = "running";
        taskProc.command = cmd;
        taskProc.running = true;
    }

    function dismissTask() {
        root.task = "";
        root.taskState = "idle";
        root.taskMsg = "";
    }

    // ── Cobalt download + remux ─────────────────────────────────────────
    function openDownload() {
        root.dlTab = "download";
        root.dlOpen = true;
    }

    function closeDownload() {
        root.dlOpen = false;
    }

    function pasteDownload() {
        dlPasteProc.running = true;
    }

    function submitDownload() {
        if (root.dlText.trim().length > 0) {
            enqueueDownload(root.dlText, root.dlMode);
            root.dlText = "";
        }
    }

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

    // One worker at a time walks the queue, so a burst of links downloads in order
    // instead of fighting over the network.
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
        id: deviceModel
    }

    ListModel {
        id: queueModel
    }

    Process {
        id: discoverProc
        command: ["bash", root.script, "discover"]
        stdout: StdioCollector {
            id: discoverOut
        }
        onExited: {
            if (root.lsState !== "scanning")
                return;
            deviceModel.clear();
            var ipRe = /^\d{1,3}(\.\d{1,3}){3}$/;
            var lines = discoverOut.text.split("\n");
            for (var i = 0; i < lines.length; i++) {
                var parts = lines[i].split("\t");
                if (parts.length === 2 && ipRe.test(parts[1].trim()))
                    deviceModel.append({ alias: parts[0].trim(), ip: parts[1].trim() });
            }
            root.lsState = "ready";
        }
    }

    Process {
        id: sendProc
        onExited: {
            root.lsState = "idle";
            root.pendingFile = "";
            root.composeText = "";
        }
    }

    Process {
        id: recvProc
        command: ["bash", root.script, "receive"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.onRecvLine(line)
        }
        onExited: if (root.recvState !== "idle") root.recvState = "idle"
    }

    Process {
        id: taskProc
        property string lastLine: ""
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var l = ("" + line).trim();
                if (l === "@AUTH") {
                    root.authStepAside();
                    return;
                }
                if (l.length > 0)
                    taskProc.lastLine = l;
            }
        }
        onExited: (exitCode) => {
            root.taskMsg = taskProc.lastLine;
            root.taskState = exitCode === 0 ? "done" : "error";
        }
    }

    Process {
        id: pasteProc
        command: ["wl-paste", "-n"]
        stdout: StdioCollector { id: pasteOut }
        onExited: root.composeText = ("" + pasteOut.text)
    }

    Process {
        id: dlPasteProc
        command: ["wl-paste", "-n"]
        stdout: StdioCollector { id: dlPasteOut }
        onExited: root.dlText = ("" + dlPasteOut.text).trim()
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

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])
}
