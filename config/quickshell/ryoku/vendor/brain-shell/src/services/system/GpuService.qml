import QtQuick
import Quickshell.Io

// Intel iGPU: frequency % via cat of sysfs rps files.
// NVIDIA dGPU: nvidia-smi when envycontrol mode is not "integrated".
//
// Exposes:
//   igpu.freqPercent  — 0–100 (act_freq / max_freq * 100)
//   igpu.curMhz       — e.g. "650 MHz"
//   igpu.maxMhz       — e.g. "1100 MHz"
//
//   dgpu.active       — false when envycontrol is "integrated"
//   dgpu.usagePercent — 0–100
//   dgpu.usedVram     — e.g. "2048 MB"
//   dgpu.totalVram    — e.g. "4096 MB"

QtObject {
    id: root

    property bool   active:   true
    property string envyMode: "integrated"

    property QtObject igpu: QtObject {
        property real   freqPercent: 0.0
        property string curMhz:     "— MHz"
        property string maxMhz:     "— MHz"
    }

    property QtObject dgpu: QtObject {
        property bool   active:       false
        property real   usagePercent: 0.0
        property string usedVram:     "— MB"
        property string totalVram:    "— MB"
    }

    // ── Intel act freq ────────────────────────────────────────────────────────
    property real _actMhz: 0
    property real _maxMhz: 0

    property var _actProc: Process {
        command: ["cat", "/sys/class/drm/card1/gt/gt0/rps_act_freq_mhz"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var a = parseFloat(text.trim())
                if (!isNaN(a)) {
                    root._actMhz   = a
                    root.igpu.curMhz = a + " MHz"
                    if (root._maxMhz > 0)
                        root.igpu.freqPercent = Math.round((a / root._maxMhz) * 100)
                }
            }
        }
    }

    // ── Intel max freq ────────────────────────────────────────────────────────
    property var _maxProc: Process {
        command: ["cat", "/sys/class/drm/card1/gt/gt0/rps_max_freq_mhz"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var m = parseFloat(text.trim())
                if (!isNaN(m)) {
                    root._maxMhz     = m
                    root.igpu.maxMhz = m + " MHz"
                }
            }
        }
    }

    // ── NVIDIA dGPU ───────────────────────────────────────────────────────────
    property var _nvProc: Process {
        command: [
            "nvidia-smi",
            "--query-gpu=utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var line  = text.trim()
                if (line === "") return
                var parts = line.split(",").map(function(s) { return s.trim() })
                if (parts.length < 3) return
                root.dgpu.active       = true
                root.dgpu.usagePercent = parseFloat(parts[0]) || 0
                root.dgpu.usedVram     = parts[1] + " MB"
                root.dgpu.totalVram    = parts[2] + " MB"
            }
        }
    }

    // ── Poll timers ───────────────────────────────────────────────────────────
    property var _igpuTimer: Timer {
        interval: 1000
        running:  root.active
        repeat:   true
        onTriggered: {
            _actProc.running = false
            _actProc.running = true
            _maxProc.running = false
            _maxProc.running = true
        }
    }

    property var _nvTimer: Timer {
        interval: 1000
        running:  root.active && root.envyMode !== "integrated"
        repeat:   true
        onTriggered: {
            _nvProc.running = false
            _nvProc.running = true
        }
    }

    // ── dGPU active state follows envyMode ────────────────────────────────────
    onEnvyModeChanged: {
        if (envyMode === "integrated") {
            dgpu.active       = false
            dgpu.usagePercent = 0
            dgpu.usedVram     = "— MB"
            dgpu.totalVram    = "— MB"
        }
    }

    Component.onCompleted: {
        _actProc.running = true
        _maxProc.running = true
        if (envyMode !== "integrated")
            _nvProc.running = true
    }
}
