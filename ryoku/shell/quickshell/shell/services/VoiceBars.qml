pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// mic spectrum for the voice surface. mirrors AudioBars, but cava reads
// the default *input* (the mic Voxtype records from, resolved via
// `pactl get-default-source`) instead of the playback monitor, so the
// bars track what's actually spoken. `active` runs it only while the
// voice surface is open. bars sit near zero on silence (the surface
// draws that as a flat line) and rise as the user speaks. small noise
// gate (`floor`) keeps room tone from rippling the resting line.
Singleton {
    id: root

    property bool active: false
    readonly property int bars: 16
    readonly property real floor: 0.06
    property var levels: root.flat()
    property real lastReadMs: 0

    Process {
        id: cavaProc
        // read the mic via pulse: cava's pipewire backend quits within seconds here, stalling and flapping the wave; exec so the surface's SIGTERM reaps cava with no orphaned mic capture.
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; src=$(pactl get-default-source 2>/dev/null); cfg=\"${XDG_RUNTIME_DIR:-/tmp}/ryoku-cava-voice.conf\"; printf '%s\\n' '[general]' 'framerate = 30' 'bars = 16' '' '[input]' 'method = pulse' \"source = $src\" 'active = 1' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 60' > \"$cfg\"; exec cava -p \"$cfg\""]
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

    // cava sleeps and stops emitting frames once the mic is idle, so the
    // bars would otherwise freeze on the last spoken peak. settle back to
    // flat when no frame has arrived recently.
    Timer {
        interval: 120
        running: root.active
        repeat: true
        onTriggered: if (Date.now() - root.lastReadMs > 200) root.levels = root.flat()
    }

    onActiveChanged: {
        levels = flat();
        lastReadMs = 0;
    }

    function flat() {
        var a = [];
        for (var i = 0; i < bars; i++)
            a.push(0);
        return a;
    }

    function norm(v) {
        var n = parseInt(v);
        if (isNaN(n))
            return 0;
        var f = Math.max(0, Math.min(1, n / 100.0));
        return f < root.floor ? 0 : f;
    }

    function readBars(line) {
        var parts = line.trim().split(/[;\s]+/);
        if (parts.length < bars)
            return;
        var a = [];
        for (var i = 0; i < bars; i++)
            a.push(norm(parts[i]));
        levels = a;
        lastReadMs = Date.now();
    }
}
