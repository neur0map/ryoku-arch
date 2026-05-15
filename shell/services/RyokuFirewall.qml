pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs
import qs.modules.common

/**
 * Ryoku Firewall service: exposes UFW status and guarded firewall actions
 * for the right sidebar. Read-only refresh uses ryoku-firewall's non-root
 * parser. Mutations go through the helper's pkexec path and report via a
 * per-user last-op manifest.
 */
Singleton {
    id: root

    property string backend: "ufw"
    property bool commandAvailable: false
    property bool enabled: false
    property bool serviceActive: false
    property string logging: "unknown"
    property var policies: ({ incoming: "unknown", outgoing: "unknown", routed: "unknown" })
    property var rules: []
    property bool busy: false
    property string lastError: ""
    property string lastRefresh: ""
    property bool tabOpen: false

    readonly property string _manifestPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ryoku/firewall/last-op.json"

    function helperPath(name: string): string {
        var ryokuPath = Quickshell.env("RYOKU_PATH")
        if (!ryokuPath || ryokuPath.length === 0) {
            ryokuPath = Quickshell.env("HOME") + "/.local/share/ryoku"
        }
        return ryokuPath + "/bin/" + name
    }

    Process {
        id: statusProc
        command: [root.helperPath("ryoku-firewall"), "status"]
        stdout: StdioCollector {
            onStreamFinished: root._parseStatus(this.text || "")
        }
    }

    Timer {
        running: GlobalStates.sidebarRightOpen && root.tabOpen
        interval: 5000
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    FileView {
        path: root._manifestPath
        watchChanges: true
        onFileChanged: { reload(); root._parseOpManifest(text()) }
        onLoadFailed: (err) => { /* expected before first firewall action */ }
    }

    Timer {
        id: busyTimeout
        interval: 45000
        repeat: false
        onTriggered: {
            root.busy = false
            root.lastError = ""
        }
    }

    Component.onCompleted: refresh()

    function refresh(): void {
        statusProc.running = true
    }

    function addRule(action: string, direction: string, protocol: string, port: string, remote: string, comment: string): void {
        root._run(["add", action, direction, protocol, port, remote || "any", comment || ""])
    }

    function deleteRule(number: int): void {
        root._run(["delete", String(number)])
    }

    function enableFirewall(): void {
        root._run(["enable"])
    }

    function disableFirewall(): void {
        root._run(["disable"])
    }

    function reloadFirewall(): void {
        root._run(["reload"])
    }

    function restoreDefaults(): void {
        root._run(["restore-defaults"])
    }

    function setDefaultPolicy(policy: string, target: string): void {
        root._run(["default", policy, target])
    }

    function clearError(): void {
        root.lastError = ""
    }

    function _run(args: var): void {
        if (root.busy) return
        root.busy = true
        root.lastError = ""
        busyTimeout.restart()
        Quickshell.execDetached([root.helperPath("ryoku-firewall")].concat(args))
    }

    function _parseStatus(jsonText: string): void {
        const trimmed = (jsonText || "").trim()
        if (trimmed.length === 0) return

        try {
            const d = JSON.parse(trimmed)
            root.backend = d.backend || "ufw"
            root.commandAvailable = d.commandAvailable ?? false
            root.enabled = d.enabled ?? false
            root.serviceActive = d.serviceActive ?? false
            root.logging = d.logging || "unknown"
            root.policies = d.policies || ({ incoming: "unknown", outgoing: "unknown", routed: "unknown" })
            root.rules = Array.isArray(d.rules) ? d.rules : []
            root.lastRefresh = Qt.formatTime(new Date(), "HH:mm:ss")
            if (!root.commandAvailable) root.lastError = "ufw is not installed"
        } catch (e) {
            root.lastError = "could not parse firewall status"
        }
    }

    function _parseOpManifest(jsonText: string): void {
        const trimmed = (jsonText || "").trim()
        if (trimmed.length === 0) return

        try {
            const d = JSON.parse(trimmed)
            const status = d.status || ""
            if (status === "ok") {
                root.busy = false
                root.lastError = ""
                busyTimeout.stop()
                root.refresh()
            } else if (status === "cancelled") {
                root.busy = false
                root.lastError = ""
                busyTimeout.stop()
            } else if (status === "error") {
                root.busy = false
                root.lastError = d.error || "unknown firewall error"
                busyTimeout.stop()
                root.refresh()
            }
        } catch (e) {
            // FileView can observe an in-progress truncate/write. The next
            // change event carries the complete JSON.
        }
    }
}
