pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// high-resolution playback spectrum for the desktop visualiser. mirrors the
// pill's AudioBars but reads the PipeWire playback monitor at 64 bands /
// 60fps so the whole desktop sweep stays smooth. `active` gates the cava
// process; levels settle to a flat rest when cava stops emitting (system
// silent, or a restart gap) so the spectrum never freezes on the last peak.
Singleton {
    id: root

    property bool active: false
    property int bars: 64

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
        // default sink's monitor via pulse (cava's pipewire backend quits within seconds here); fall back to cava's own "auto" pick when no default sink is resolved yet, so a pipewire startup race never bakes an empty "source = .monitor" that reads nothing. exec so quickshell's SIGTERM reaches cava, leaving no orphaned analyser when the surface unloads.
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; sink=$(pactl get-default-sink 2>/dev/null); [ -n \"$sink\" ] && mon=\"$sink.monitor\" || mon=auto; cfg=\"${XDG_RUNTIME_DIR:-/tmp}/ryoku-cava-visualizer.conf\"; printf '%s\\n' '[general]' 'framerate = 60' 'bars = " + root.bars + "' '' '[input]' 'method = pulse' \"source = $mon\" '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 45' > \"$cfg\"; exec cava -p \"$cfg\""]
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

    // restart cava when the band count changes so its config picks up new bars.
    Timer {
        id: barsRestart
        interval: 300
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

    onBarsChanged: {
        levels = flat(0.02);
        if (root.active) {
            cavaProc.running = false;
            barsRestart.restart();
        }
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
