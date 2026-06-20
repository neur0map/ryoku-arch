pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Update data for the Hub's Updates section, wired to `ryoku status --json`.
 *
 * The installed version, the pending-update count, and the list of pending
 * package updates are all live. When the system is current the list is empty and
 * the section shows the up-to-date state; `check()` re-runs the check (the CLI
 * uses checkupdates, which syncs a private database and needs no root).
 */
Singleton {
    id: root

    property bool available: false
    property string currentVersion: ""
    property string latestVersion: ""
    readonly property string branch: "main"
    property int behind: 0

    // Newest pacman view: [{ name, old, new }]. Empty when the system is current.
    property var updates: []

    property var lastChecked: null
    property int tick: 0
    readonly property string checkedAgo: {
        root.tick;  // re-evaluate as the clock ticks
        if (!root.lastChecked)
            return "not yet";
        var s = Math.floor((Date.now() - root.lastChecked.getTime()) / 1000);
        if (s < 10)
            return "just now";
        if (s < 60)
            return s + "s ago";
        var m = Math.floor(s / 60);
        if (m < 60)
            return m + "m ago";
        var h = Math.floor(m / 60);
        if (h < 24)
            return h + "h ago";
        return Math.floor(h / 24) + "d ago";
    }

    function check() {
        statusProc.running = true;
    }

    function apply(t) {
        try {
            var o = JSON.parse(t);
            root.currentVersion = o.installedVersion || "";
            root.latestVersion = o.latestVersion || "";
            root.behind = o.pendingUpdates || 0;
            root.available = root.behind > 0;
            root.updates = o.updates || [];
            root.lastChecked = new Date();
        } catch (e) {
            root.available = false;
            root.behind = 0;
            root.updates = [];
        }
    }

    Process {
        id: statusProc
        command: ["ryoku", "status", "--json"]
        stdout: StdioCollector {
            onStreamFinished: root.apply(this.text)
        }
    }

    // Keep the "checked Xm ago" line live.
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick++
    }

    Component.onCompleted: root.check()
}
