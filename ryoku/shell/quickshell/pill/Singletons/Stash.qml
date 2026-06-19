pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * File stash bridge: a live snapshot of ~/Downloads/Stash and the back-end for
 * the stash surface's rail actions. The FolderListModel watches the directory
 * (created on first load) so the grid stays current without polling; openFile,
 * removeFile, clearAll and addUrl drive it through detached coreutils.
 *
 * Rail actions run helper scripts under ~/.config/hypr/scripts: LocalSend
 * (openSendPicker / openSendAll kick a ~2s LAN discovery, sendTo uploads the
 * pending file or the whole stash to the picked device), install (AppImage or
 * tarball -> app launcher), compress (ffmpeg) and download (yt-dlp). lsState
 * (idle|scanning|ready|sending) drives the device picker; task / taskState /
 * taskMsg drive the install/compress/download progress overlay.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: home + "/Downloads/Stash"
    readonly property string script: home + "/.config/hypr/scripts/localsend.sh"
    readonly property string scriptDir: home + "/.config/hypr/scripts"

    readonly property alias files: files
    readonly property int count: files.count

    readonly property alias deviceModel: deviceModel
    readonly property alias discoverProc: discoverProc

    property string lsState: "idle"
    property string pendingFile: ""
    property bool sendingAll: false
    property string task: ""
    property string taskState: "idle"
    property string taskMsg: ""

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

    function openSendPicker(file) {
        root.sendingAll = false;
        root.pendingFile = file;
        deviceModel.clear();
        root.lsState = "scanning";
        discoverProc.running = true;
    }

    function openSendAll() {
        if (root.count === 0)
            return;
        root.sendingAll = true;
        root.pendingFile = "";
        deviceModel.clear();
        root.lsState = "scanning";
        discoverProc.running = true;
    }

    function sendTo(ip) {
        root.lsState = "sending";
        sendProc.command = root.sendingAll
            ? ["bash", root.script, "send-all", root.dir, ip]
            : ["bash", root.script, "send", root.pendingFile, ip];
        sendProc.running = true;
    }

    // Rail actions run a helper over the stash and report through task/taskState;
    // the surface shows a progress overlay keyed off them.
    function runTask(name, cmd) {
        root.task = name;
        root.taskMsg = "";
        root.taskState = "running";
        taskProc.command = cmd;
        taskProc.running = true;
    }

    function installStash() {
        if (root.count > 0)
            runTask("install", ["bash", root.scriptDir + "/stash-install.sh"]);
    }

    function compressStash() {
        if (root.count > 0)
            runTask("compress", ["bash", root.scriptDir + "/stash-compress.sh"]);
    }

    function download(url) {
        var u = ("" + url).trim();
        if (u.length > 0)
            runTask("download", ["bash", root.scriptDir + "/stash-download.sh", u]);
    }

    // The download tab pulls its link from the clipboard (copy a URL, tap
    // download), so it needs no in-surface text field or keyboard grab.
    function downloadFromClipboard() {
        root.task = "download";
        root.taskMsg = "";
        root.taskState = "running";
        clipProc.running = true;
    }

    function dismissTask() {
        root.task = "";
        root.taskState = "idle";
        root.taskMsg = "";
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
            root.sendingAll = false;
        }
    }

    Process {
        id: taskProc
        stdout: StdioCollector { id: taskOut }
        onExited: (exitCode) => {
            var lines = ("" + taskOut.text).split("\n");
            var last = "";
            for (var i = 0; i < lines.length; i++) {
                if (lines[i].trim().length > 0)
                    last = lines[i].trim();
            }
            root.taskMsg = last;
            root.taskState = exitCode === 0 ? "done" : "error";
        }
    }

    Process {
        id: clipProc
        command: ["wl-paste", "-n"]
        stdout: StdioCollector { id: clipOut }
        onExited: {
            var u = ("" + clipOut.text).trim();
            if (/^https?:\/\/\S+/.test(u))
                root.download(u);
            else {
                root.taskState = "error";
                root.taskMsg = "Copy a link first, then tap download";
            }
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])
}
