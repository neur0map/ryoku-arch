pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Plugin discovery + runtime registry. Runs discover.sh (scan plugin dirs, merge
 * the user's plugins.json placement, keep only enabled ones) and exposes the
 * result as `plugins`: an array of { id, dir, manifest, placement }. The host
 * config (shell.qml) instantiates each plugin's content into the host the user
 * chose. Re-runs on `reload()` (the daemon calls it after a placement change)
 * and watches plugins.json so a Settings edit retunes with no restart.
 *
 * The discover script path is resolved from RYOKU_SHELL_DIR in dev, else the
 * installed quickshell tree.
 */
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

    // Watch the user's placement file: any enable/placement/settings change
    // re-discovers, so the shell retunes live like the rest of the desktop.
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reload()
        onLoaded: root.reload()
    }
}
