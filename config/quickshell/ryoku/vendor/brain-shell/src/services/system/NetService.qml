import QtQuick
import Quickshell.Io

// Detects active interface via ip route, then
// deltas /proc/net/dev byte counters every second via cat.
//
// Exposes:
//   string iface      — e.g. "wlan0"
//   string upSpeed    — e.g. "1.2 MB/s"
//   string downSpeed  — e.g. "3.4 MB/s"

QtObject {
    id: root

    property bool   active:    true
    property string iface:     "—"
    property string upSpeed:   "0 KB/s"
    property string downSpeed: "0 KB/s"

    property real _prevRx:    0
    property real _prevTx:    0
    property bool _firstRead: true

    // ── Detect active interface — re-checked on every poll tick ──────────────
    // Running once at startup missed interface changes (VPN, cable, network switch).
    // Now re-runs every second alongside the stats read. If iface changes, counters
    // reset so the first delta is not a huge spike.
    property var _ifaceProc: Process {
        command: ["sh", "-c",
            "ip route get 1.1.1.1 2>/dev/null" +
            " | awk '/dev/{for(i=1;i<=NF;i++) if($i==\"dev\") print $(i+1)}'"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim()
                if (name !== "" && name !== root.iface) {
                    root.iface      = name
                    root._firstRead = true   // reset counters — avoid spike
                    root._prevRx    = 0
                    root._prevTx    = 0
                }
            }
        }
    }

    // ── /proc/net/dev via cat ─────────────────────────────────────────────────
    property var _proc: Process {
        command: ["cat", "/proc/net/dev"]
        running: false
        stdout: StdioCollector {
            onStreamFinished: root._parse(text)
        }
    }

    property var _timer: Timer {
        interval: 1000
        running:  root.active
        repeat:   true
        onTriggered: {
            // Re-detect interface every tick — catches VPN, cable, network changes
            _ifaceProc.running = false
            _ifaceProc.running = true
            _proc.running = false
            _proc.running = true
        }
    }

    function _parse(text) {
        if (root.iface === "—") return
        var lines = text.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            if (!line.startsWith(root.iface + ":")) continue

            var parts = line.split(":")[1].trim().split(/\s+/)
            var rx = parseFloat(parts[0])
            var tx = parseFloat(parts[8])

            if (!root._firstRead) {
                var dRx = Math.max(0, rx - root._prevRx)
                var dTx = Math.max(0, tx - root._prevTx)
                root.downSpeed = root._fmt(dRx)
                root.upSpeed   = root._fmt(dTx)
            }
            root._firstRead = false
            root._prevRx = rx
            root._prevTx = tx
            break
        }
    }

    function _fmt(bytesPerSec) {
        if (bytesPerSec >= 1024 * 1024)
            return (Math.round(bytesPerSec / 1024 / 1024 * 10) / 10) + " MB/s"
        if (bytesPerSec >= 1024)
            return Math.round(bytesPerSec / 1024) + " KB/s"
        return Math.round(bytesPerSec) + " B/s"
    }

    Component.onCompleted: {
        _ifaceProc.running = true
        _proc.running = true
    }
}
