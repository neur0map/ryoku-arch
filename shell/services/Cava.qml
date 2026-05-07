pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Wraps the cava CLI in raw output mode. Exposes `bars` (7 floats 0-1).
// Started/stopped on demand to avoid CPU cost when idle.
Singleton {
    id: root

    property int barCount: 7
    property var bars: Array(barCount).fill(0)
    property bool active: cavaProc.running
    property bool unavailable: false  // true if cava binary missing

    function start() {
        if (root.unavailable) return;
        if (!cavaProc.running) cavaProc.running = true;
    }

    function stop() {
        if (cavaProc.running) cavaProc.running = false;
        bars = Array(barCount).fill(0);
    }

    Process {
        id: probeProc
        command: ["/usr/bin/sh", "-c", "command -v cava >/dev/null 2>&1"]
        onExited: (exitCode) => { root.unavailable = (exitCode !== 0) }
    }

    Component.onCompleted: probeProc.running = true

    Process {
        id: cavaProc
        running: false
        // Raw 8-bit output, capped at 30fps, 7 bars. cava reads its config from
        // a file generated at startup.
        command: ["/usr/bin/sh", "-c", `
            cfg=$(mktemp)
            cat > "$cfg" <<EOF
[general]
bars = ${root.barCount}
framerate = 30

[output]
method = raw
raw_target = /dev/stdout
data_format = ascii
ascii_max_range = 100
EOF
            exec cava -p "$cfg"
        `]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                const parts = line.split(";").filter(s => s.length > 0);
                if (parts.length !== root.barCount) return;
                const next = [];
                for (let i = 0; i < parts.length; i++) {
                    const v = parseInt(parts[i], 10);
                    next.push(Number.isFinite(v) ? Math.max(0, Math.min(1, v / 100.0)) : 0);
                }
                root.bars = next;
            }
        }
    }
}
