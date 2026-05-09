pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import qs.modules.common

/**
 * Ryoku Hosts service: parses the ryoku-hosts managed block from
 * /etc/hosts and exposes add/remove action methods that go through
 * `pkexec` (the existing WafflePolkit UI catches the auth prompt).
 * No polling: a FileView watches /etc/hosts directly, and a second
 * FileView watches the helper's status manifest for completion + errors.
 */
Singleton {
    id: root

    // ── public state ──────────────────────────────────────────────
    property var entries: []          // [{ip, domain}, ...]
    property bool busy: false         // true while a pkexec helper is in flight
    property string lastError: ""     // populated on helper failure
    property bool tabOpen: false      // driven by parent sidebar layout (symmetry; not load-bearing)

    // ── parse /etc/hosts managed block ────────────────────────────
    Process {
        id: parseProc
        command: ["awk",
            "/^# >>> ryoku-hosts \\(managed\\) >>>/,/^# <<< ryoku-hosts \\(managed\\) <<</",
            "/etc/hosts"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = []
                const lines = (this.text || "").split("\n")
                for (const line of lines) {
                    const trimmed = line.trim()
                    if (trimmed.length === 0) continue
                    if (trimmed.startsWith("#")) continue   // skip markers + advisory
                    const parts = trimmed.split(/[ \t]+/)
                    if (parts.length < 2) continue
                    out.push({ ip: parts[0], domain: parts[1] })
                }
                root.entries = out
            }
        }
    }
    Component.onCompleted: parseProc.running = true

    // ── watch /etc/hosts: any external write triggers a re-parse ──
    FileView {
        path: "/etc/hosts"
        watchChanges: true
        onFileChanged: { reload(); parseProc.running = true }
        onLoadFailed: (err) => { /* /etc/hosts always exists; ignore */ }
    }

    // ── watch helper's status manifest for op completion ──────────
    FileView {
        id: opManifest
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
              + "/ryoku/hosts/last-op.json"
        watchChanges: true
        onFileChanged: { reload(); root._parseOpManifest(text()) }
        onLoaded: root._parseOpManifest(text())
        onLoadFailed: (err) => { /* expected before first op */ }
    }

    function _parseOpManifest(jsonText: string): void {
        try {
            const d = JSON.parse(jsonText)
            const status = d.status || ""
            if (status === "ok" || status === "ok-noop") {
                root.busy = false
                root.lastError = ""
                busyTimeout.stop()
                parseProc.running = true
            } else if (status === "cancelled") {
                root.busy = false
                root.lastError = ""    // user cancel: silent
                busyTimeout.stop()
            } else if (status === "error") {
                root.busy = false
                root.lastError = d.error || "unknown error"
                busyTimeout.stop()
            }
        } catch (e) {
            root.busy = false
            root.lastError = "could not parse helper status"
            busyTimeout.stop()
        }
    }

    // ── safety: clear busy if helper hangs (user wanders off) ─────
    Timer {
        id: busyTimeout
        interval: 30000
        repeat: false
        onTriggered: {
            root.busy = false
            root.lastError = ""
        }
    }

    // ── public API ────────────────────────────────────────────────
    function add(ip: string, domain: string): void {
        if (root.busy) return
        if (!ip || !domain) return
        root.busy = true
        root.lastError = ""
        busyTimeout.restart()
        Quickshell.execDetached(["ryoku-hosts-edit", "add", ip, domain])
    }

    function remove(ip: string, domain: string): void {
        if (root.busy) return
        if (!ip || !domain) return
        root.busy = true
        root.lastError = ""
        busyTimeout.restart()
        Quickshell.execDetached(["ryoku-hosts-edit", "remove", ip, domain])
    }

    function clearError(): void {
        root.lastError = ""
    }
}
