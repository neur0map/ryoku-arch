import QtQuick
import Quickshell.Io

// Tracks auto-cpufreq daemon status, the kernel governor, and current freq.
//
// Reading strategy:
//   1. systemctl is-active auto-cpufreq         → daemonActive
//   2. cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
//      → reads ALL cores, picks the dominant governor
//      → activeProfile: "performance" | "powersave"
//   3. cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq
//      → averages kHz across all cores → curFreqStr
//
// Exposes:
//   string governor      — dominant sysfs value e.g. "powersave"
//   string activeProfile — "performance" | "powersave"
//   bool   daemonActive  — true if auto-cpufreq.service is running
//   bool   busy
//   string curFreqStr    — average frequency e.g. "2.40 GHz"
//   function setActiveProfile(profile)  — "performance" | "powersave"

QtObject {
    id: root

    property string governor:      "—"
    property string activeProfile: "powersave"
    property bool   daemonActive:  false
    property bool   busy:          false
    property string curFreqStr:    "— GHz"

    property string _pendingProfile: ""

    // ── Daemon status check ───────────────────────────────────────────────────
    property var _daemonProc: Process {
        command: ["systemctl", "is-active", "auto-cpufreq"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                root.daemonActive = text.trim() === "active"
            }
        }
    }

    // ── Governor reader (all cores) ───────────────────────────────────────────
    // Picks dominant governor, then maps it to "performance" or "powersave".
    property var _govProc: Process {
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(function(l) { return l !== "" })
                if (lines.length === 0) return

                var counts = {}
                for (var i = 0; i < lines.length; i++) {
                    var g = lines[i].trim()
                    counts[g] = (counts[g] || 0) + 1
                }

                var dominant = lines[0].trim()
                var max = 0
                var keys = Object.keys(counts)
                for (var j = 0; j < keys.length; j++) {
                    if (counts[keys[j]] > max) {
                        max = counts[keys[j]]
                        dominant = keys[j]
                    }
                }

                root.governor      = dominant
                root.activeProfile = (dominant === "performance") ? "performance" : "powersave"
            }
        }
    }

    // ── Current frequency reader (all cores) ─────────────────────────────────
    // scaling_cur_freq is in kHz. Average across all cores → format as GHz.
    property var _freqProc: Process {
        command: ["sh", "-c", "cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = text.trim().split("\n").filter(function(l) { return l !== "" })
                if (lines.length === 0) return

                var sum = 0
                for (var i = 0; i < lines.length; i++)
                    sum += parseFloat(lines[i].trim())

                var avgGhz = (sum / lines.length) / 1e6
                root.curFreqStr = avgGhz.toFixed(2) + " GHz"
            }
        }
    }

    // ── Set profile ───────────────────────────────────────────────────────────
    // Writes the requested governor to all cores via pkexec tee.
    property var _setProc: Process {
        command: []
        running: false
        onRunningChanged: {
            if (!running) {
                root.busy = false
                root._poll()
            }
        }
    }

    function setActiveProfile(profile) {
        if (root.busy) return
        root.busy = true

        var gov = (profile === "performance") ? "performance" : "powersave"
        _setProc.command = [
            "sh", "-c",
            "echo " + gov + " | tee /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor"
        ]
        _setProc.running = false
        _setProc.running = true
    }

    // ── Poll timer ────────────────────────────────────────────────────────────
    property var _pollTimer: Timer {
        interval: 2000
        running:  true
        repeat:   true
        onTriggered: root._poll()
    }

    function _poll() {
        _govProc.running    = false
        _govProc.running    = true
        _freqProc.running   = false
        _freqProc.running   = true
        _daemonProc.running = false
        _daemonProc.running = true
    }

    Component.onCompleted: _poll()
}
