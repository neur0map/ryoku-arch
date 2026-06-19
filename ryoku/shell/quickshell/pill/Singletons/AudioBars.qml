pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property real b0: 0.14
    property real b1: 0.22
    property real b2: 0.36
    property real b3: 0.28
    property real b4: 0.18
    property real b5: 0.30
    property real phase: 0
    property real lastReadMs: 0

    Process {
        id: cavaProc
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=$(mktemp); printf '%s\\n' '[general]' 'framerate = 30' 'bars = 6' '' '[input]' 'method = pipewire' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' '' '[smoothing]' 'noise_reduction = 77' > \"$cfg\"; cava -p \"$cfg\"; rc=$?; rm -f \"$cfg\"; exit $rc"]
        running: root.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.readBars(line)
        }
        onExited: if (root.active) restartTimer.restart()
    }

    Timer {
        id: restartTimer
        interval: 1200
        onTriggered: if (root.active && !cavaProc.running) cavaProc.running = true
    }

    Timer {
        interval: 70
        running: root.active
        repeat: true
        onTriggered: {
            root.phase += 0.31;
            if (Date.now() - root.lastReadMs <= 220)
                return;
            root.b0 = wave(0);
            root.b1 = wave(1);
            root.b2 = wave(2);
            root.b3 = wave(3);
            root.b4 = wave(4);
            root.b5 = wave(5);
        }
    }

    onActiveChanged: if (!active) {
        b0 = 0.12; b1 = 0.12; b2 = 0.12; b3 = 0.12; b4 = 0.12; b5 = 0.12;
    } else {
        lastReadMs = 0;
    }

    function wave(i) {
        return 0.16 + 0.58 * Math.abs(Math.sin(phase + i * 0.73));
    }

    function norm(v) {
        var n = parseInt(v);
        if (isNaN(n))
            return 0.12;
        return Math.max(0.08, Math.min(1.0, n / 100.0));
    }

    function readBars(line) {
        var parts = line.trim().split(/[;\s]+/);
        if (parts.length < 6)
            return;
        lastReadMs = Date.now();
        b0 = norm(parts[0]);
        b1 = norm(parts[1]);
        b2 = norm(parts[2]);
        b3 = norm(parts[3]);
        b4 = norm(parts[4]);
        b5 = norm(parts[5]);
    }
}
