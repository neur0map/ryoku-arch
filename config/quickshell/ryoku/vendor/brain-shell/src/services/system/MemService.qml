import QtQuick
import Quickshell.Io

// Reads /proc/meminfo every 2s via cat (FileView can't read virtual fs).
// Exposes:
//   real usagePercent   — 0.0 to 100.0
//   real usedGb
//   real totalGb
//   string usedStr      — e.g. "11.2 GB"
//   string totalStr     — e.g. "16.0 GB"

QtObject {
    id: root

    property bool active:       true
    property real usagePercent: 0.0
    property real usedGb:       0.0
    property real totalGb:      0.0
    property string usedStr:    "—"
    property string totalStr:   "—"

    property var _proc: Process {
        command: ["cat", "/proc/meminfo"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    property var _timer: Timer {
        interval: 2000
        running:  root.active
        repeat:   true
        onTriggered: {
            _proc.running = false
            _proc.running = true
        }
    }

    function _parse(text) {
        var total = 0, avail = 0
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/)
            if (parts[0] === "MemTotal:")     total = parseFloat(parts[1])
            if (parts[0] === "MemAvailable:") avail = parseFloat(parts[1])
        }
        if (total <= 0) return

        var used = total - avail
        root.totalGb      = Math.round(total / 1024 / 1024 * 10) / 10
        root.usedGb       = Math.round(used  / 1024 / 1024 * 10) / 10
        root.usagePercent = Math.round(used / total * 100)
        root.usedStr      = root.usedGb  + " GB"
        root.totalStr     = root.totalGb + " GB"
    }

    Component.onCompleted: {
        _proc.running = true
    }
}
