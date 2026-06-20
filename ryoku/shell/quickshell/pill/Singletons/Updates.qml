pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Update state for the top-right update island.
 *
 * The availability fields are MOCK placeholders so the island can be built and
 * reviewed; wire them to `ryoku-shell` when the updater lands. The run-state
 * fields below are real: the Hub publishes an update's progress to a small
 * runtime file (see the Hub's UpdatesPage), and the island mirrors it -- a Ryoku
 * wave while the update runs, a refresh affordance on success.
 */
Singleton {
    id: root

    // --- mock availability --------------------------------------------------
    readonly property bool available: true
    readonly property int behind: 6
    readonly property string latestVersion: "2026.06.20"

    // --- live run state (mirrored from the Hub) -----------------------------
    property string runPhase: "idle"   // idle | running | success
    property real runProgress: 0

    readonly property string statePath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-update.json"

    function applyState(t) {
        try {
            var o = JSON.parse(t);
            root.runPhase = o.phase || "idle";
            root.runProgress = (typeof o.progress === "number") ? o.progress : 0;
        } catch (e) {
            root.runPhase = "idle";
            root.runProgress = 0;
        }
    }

    // Dismiss the run state (write idle); used after a refresh.
    function clearRun() {
        root.runPhase = "idle";
        root.runProgress = 0;
        state.setText("{\"phase\":\"idle\"}");
    }

    // Reload the shell so a finished update's changes take effect, then clear.
    function refresh() {
        Quickshell.execDetached(["ryoku-shell", "reload"]);
        root.clearRun();
    }

    FileView {
        id: state
        path: root.statePath
        watchChanges: true
        atomicWrites: false
        onLoaded: root.applyState(state.text())
        onFileChanged: state.reload()
        onLoadFailed: state.setText("{\"phase\":\"idle\"}")
    }
}
