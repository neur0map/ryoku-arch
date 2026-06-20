pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

/**
 * High-resolution playback spectrum for the desktop visualiser. Mirrors the
 * pill's AudioBars but reads the PipeWire playback monitor at 64 bands and 60fps
 * so the whole desktop sweep stays smooth. `active` gates the cava process, and
 * the levels settle to a flat rest when cava stops emitting (system silent or a
 * restart gap) so the spectrum never freezes on the last peak.
 */
Singleton {
    id: root

    property bool active: false
    readonly property int bars: 64

    // 0..1 per band (length == bars) and the mean energy across all bands.
    property var levels: root.flat(0.02)
    property real energy: 0
    property real lastReadMs: 0

    function flat(v) {
        var a = [];
        for (var i = 0; i < root.bars; i++)
            a.push(v);
        return a;
    }

    Process {
        id: cavaProc
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=$(mktemp); printf '%s\\n' '[general]' 'framerate = 60' 'bars = 64' '' '[input]' 'method = pipewire' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 45' > \"$cfg\"; cava -p \"$cfg\"; rc=$?; rm -f \"$cfg\"; exit $rc"]
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

    // Settle to a flat resting line when no frame arrives recently.
    Timer {
        interval: 120
        running: root.active
        repeat: true
        onTriggered: if (Date.now() - root.lastReadMs > 260) {
            root.levels = root.flat(0.02);
            root.energy = 0;
        }
    }

    onActiveChanged: {
        levels = flat(0.02);
        energy = 0;
        if (active)
            lastReadMs = 0;
    }

    function norm(v) {
        var n = parseInt(v);
        if (isNaN(n))
            return 0;
        return Math.max(0, Math.min(1, n / 100));
    }

    function readBars(line) {
        var t = line.trim();
        if (!t)
            return;
        var parts = t.split(/[;\s]+/);
        if (parts.length < root.bars)
            return;
        var out = [];
        var sum = 0;
        for (var i = 0; i < root.bars; i++) {
            var v = root.norm(parts[i]);
            out.push(v);
            sum += v;
        }
        root.levels = out;
        root.energy = sum / root.bars;
        root.lastReadMs = Date.now();
    }
}
