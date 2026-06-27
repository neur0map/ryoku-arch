pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// plugin discovery + runtime registry. discover.sh scans plugin dirs, merges
// the user's plugins.json placement, drops disabled ones, and we expose the
// result as `plugins`: { id, dir, manifest, placement }[]. host config
// (shell.qml) instantiates each plugin's content into whatever host the user
// picked. reload() re-runs (daemon calls it after a placement change), and we
// watch plugins.json so a Settings edit retunes without restart.
//
// script path: RYOKU_SHELL_DIR in dev, else the installed quickshell tree.
Singleton {
    id: root

    property var plugins: []
    property bool ready: false

    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _script: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/discover.sh"

    function reload() {
        discoverProc.running = false;
        discoverProc.running = true;
    }

    Process {
        id: discoverProc
        command: ["bash", root._script]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.plugins = JSON.parse(text || "[]");
                } catch (e) {
                    root.plugins = [];
                }
                root.ready = true;
            }
        }
    }

    // watch user's placement file: any enable/placement/settings change
    // re-discovers, so the shell retunes live like the rest of the desktop.
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
        onLoaded: root.reload()
    }
}
