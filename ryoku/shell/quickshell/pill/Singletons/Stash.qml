pragma Singleton
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io

/**
 * File stash bridge: a live snapshot of ~/Downloads/Stash plus a LocalSend
 * front-end for the stash surface. The FolderListModel watches the directory
 * (created on first load) so the grid stays current without polling; openFile,
 * removeFile, clearAll and addUrl drive it through detached coreutils. Sending
 * runs the localsend.sh helper: openSendPicker kicks a ~2s LAN discovery whose
 * tab-separated "alias\tip" lines populate deviceModel, and sendTo POSTs the
 * pending file to the chosen device. lsState (idle|scanning|ready|sending)
 * drives the picker overlay and pendingFile holds the file awaiting a target.
 */
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string dir: home + "/Downloads/Stash"
    readonly property string script: home + "/.config/hypr/scripts/localsend.sh"

    readonly property alias files: files
    readonly property int count: files.count

    readonly property alias deviceModel: deviceModel
    readonly property alias discoverProc: discoverProc

    property string lsState: "idle"
    property string pendingFile: ""

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
        root.pendingFile = file;
        deviceModel.clear();
        root.lsState = "scanning";
        discoverProc.running = true;
    }

    function sendTo(ip) {
        root.lsState = "sending";
        sendProc.command = ["bash", root.script, "send", root.pendingFile, ip];
        sendProc.running = true;
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
        }
    }

    Component.onCompleted: Quickshell.execDetached(["mkdir", "-p", root.dir])
}
