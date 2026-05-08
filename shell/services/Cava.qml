pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Wraps the cava CLI in raw output mode. Exposes `bars` (N integers 0-100,
// where N = barCount). Started/stopped on demand to avoid CPU cost when
// idle. Config and parsing pattern adapted from Brain_Shell's CavaService.
Singleton {
    id: root

    // 32 bars matches Brain_Shell's iconic dense visualizer. Even count is
    // required when cava runs stereo; we set channels=mono but keep an even
    // count for safety with cava version drift.
    property int barCount: 32
    property var bars: (function() {
        var a = []; for (var i = 0; i < barCount; i++) a.push(0); return a
    })()
    property bool active: cavaProc.running
    property bool unavailable: false  // true if cava binary missing

    function start() {
        if (root.unavailable) return;
        if (!cavaProc.running) cavaProc.running = true;
    }

    function stop() {
        if (cavaProc.running) cavaProc.running = false;
        const z = []; for (var i = 0; i < root.barCount; i++) z.push(0);
        bars = z;
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
        // Config inlined via printf (mirrors Brain_Shell's pattern). Explicit
        // bar_delimiter=59 (semicolon) and frame_delimiter=10 (LF) make the
        // output reliably line-parseable. noise_reduction smooths jitter.
        // pulse + auto source picks the default sink monitor.
        command: [
            "/usr/bin/sh", "-c",
            "mkdir -p /tmp/ryoku_shell && " +
            "printf '[general]\\nbars = " + barCount + "\\nframerate = 60\\nnoise_reduction = 77\\n\\n" +
            "[input]\\nmethod = pulse\\nsource = auto\\n\\n" +
            "[output]\\nmethod = raw\\nraw_target = /dev/stdout\\n" +
            "data_format = ascii\\nascii_max_range = 100\\nchannels = mono\\n" +
            "bar_delimiter = 59\\nframe_delimiter = 10\\n' " +
            "> /tmp/ryoku_shell/cava.ini && " +
            "exec cava -p /tmp/ryoku_shell/cava.ini 2>/dev/null"
        ]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var t = line.trim();
                if (t === "") return;
                if (t.endsWith(";")) t = t.slice(0, -1);
                const parts = t.split(";");
                if (parts.length !== root.barCount) return;
                const next = [];
                for (var i = 0; i < parts.length; i++) {
                    next.push(parseInt(parts[i], 10) || 0);
                }
                root.bars = next;
            }
        }
    }
}
