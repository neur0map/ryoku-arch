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

    readonly property string _manifestPath:
        (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state"))
        + "/ryoku/hosts/last-op.json"

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
    Component.onCompleted: {
        parseProc.running = true
        resumeReader.running = true
    }

    // ── watch /etc/hosts for external writes ─────────────────────
    // Defensive only. The privileged write is `pkexec install $tmp /etc/hosts`,
    // which unlink+creates the destination; inotify watchers on the old inode
    // get dropped. The LOAD-BEARING re-parse runs from `_parseOpManifest`'s
    // ok/ok-noop branches via `parseProc.running = true`. This FileView catches
    // hand-edits in vim, package-manager touches, and any other external write
    // that doesn't go through our helper.
    FileView {
        path: "/etc/hosts"
        watchChanges: true
        onFileChanged: { reload(); parseProc.running = true }
        onLoadFailed: (err) => { /* /etc/hosts always exists; ignore */ }
    }

    // ── watch helper's status manifest for op completion ──────────
    // The manifest can persist across shell restarts (e.g., a leftover
    // error from a verification run in another session). DO NOT call
    // _parseOpManifest from `onLoaded` — that path surfaces stale errors
    // at startup. Live op completions during the current session fire
    // `onFileChanged` and are honored normally; the startup path is
    // handled below by `resumeReader` which checks the file's mtime
    // against the current boot epoch and deletes anything stale.
    FileView {
        id: opManifest
        path: root._manifestPath
        watchChanges: true
        onFileChanged: { reload(); root._parseOpManifest(text()) }
        onLoadFailed: (err) => { /* expected before first op */ }
    }

    // Startup-only: ignore manifests written by previous shell sessions.
    // If the file's mtime is before the current boot, the contents are
    // not relevant to this session (could be a debugging artifact, a
    // crash leftover, or a half-finished op from a prior boot). Delete
    // it so the bar/sidebar shows fresh state on first paint.
    Process {
        id: resumeReader
        running: false
        command: ["/usr/bin/bash", "-c", `
            status_file="$1"
            if [ ! -f "$status_file" ]; then exit 0; fi
            now=$(/usr/bin/date +%s)
            if read -r uptime _ < /proc/uptime; then
                uptime_s=$(/usr/bin/printf '%s\n' "$uptime" | /usr/bin/cut -d. -f1)
            else
                uptime_s=0
            fi
            boot_epoch=$((now - uptime_s))
            mtime=$(/usr/bin/stat -c %Y "$status_file" 2>/dev/null || echo 0)
            if [ "$mtime" -lt "$boot_epoch" ]; then
                echo "stale"
            else
                /usr/bin/cat "$status_file"
            fi
        `, "_", root._manifestPath]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = (this.text || "").trim()
                if (out === "stale") {
                    clearManifestProc.running = true
                    return
                }
                if (out.length === 0) return
                root._parseOpManifest(out)
            }
        }
    }

    Process {
        id: clearManifestProc
        running: false
        command: ["rm", "-f", root._manifestPath]
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
