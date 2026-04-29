import QtQuick
import Quickshell.Io

// Runs df every 15s and exposes real block devices as a list model.
//
// Exposes:
//   var disks — ListModel with objects:
//     { source, mount, usedPct, usedStr, totalStr }

QtObject {
    id: root

    property bool active: true
    property var  disks:  []

    property var _proc: Process {
        command: [
            "sh", "-c",
            "df -BM --output=source,size,used,pcent,target 2>/dev/null" +
            " | grep '^/dev/' | grep -v 'tmpfs\\|loop'"
        ]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    property var _timer: Timer {
        interval: 15000
        running:  root.active
        repeat:   true
        onTriggered: root._run()
    }

    function _run() {
        _proc.running = false
        _proc.running = true
    }

    function _parse(text) {
        var lines  = text.trim().split("\n")
        var result = []

        for (var i = 0; i < lines.length; i++) {
            var parts = lines[i].trim().split(/\s+/)
            // source  size  used  pcent  target
            if (parts.length < 5) continue

            var source = parts[0]
            var total  = parts[1]   // e.g. "230004M"
            var used   = parts[2]   // e.g. "180000M"
            var pct    = parts[3]   // e.g. "78%"
            var mount  = parts[4]

            // Shorten source: /dev/nvme0n1p2 → nvme0n1p2, /dev/sda1 → sda1
            var shortSource = source.replace("/dev/", "")

            result.push({
                source:   shortSource,
                mount:    mount,
                usedPct:  parseInt(pct) || 0,
                usedStr:  _fmt(used),
                totalStr: _fmt(total)
            })
        }

        root.disks = result
    }

    // Convert "180000M" → "175 GB" or keep as MB
    function _fmt(mibStr) {
        var n = parseInt(mibStr)
        if (isNaN(n)) return mibStr
        if (n >= 1024) return (n / 1024).toFixed(0) + " GB"
        return n + " MB"
    }

    Component.onCompleted: _run()
}
