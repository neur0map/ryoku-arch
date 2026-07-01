pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Playback spectrum for the now-playing card's wave backdrop. A trimmed sibling
// of the desktop visualiser's Spectrum: fewer bands and 30fps because it feeds a
// small ambient wave, not a full-screen sweep. `active` gates the cava process
// so nothing runs while the launcher is hidden or paused; levels settle flat
// when cava stops emitting (silence or a restart gap) so the wave never freezes
// on its last peak. Reads the PipeWire playback monitor, keyless.
Singleton {
    id: root

    property bool active: false
    property int bars: 48

    // 0..1 per band (length == bars) + mean energy across all bands.
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
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=$(mktemp); printf '%s\\n' '[general]' 'framerate = 30' 'bars = " + root.bars + "' '' '[input]' 'method = pipewire' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 45' > \"$cfg\"; cava -p \"$cfg\"; rc=$?; rm -f \"$cfg\"; exit $rc"]
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

    // settle to a flat resting line when no frame has arrived in a bit.
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
