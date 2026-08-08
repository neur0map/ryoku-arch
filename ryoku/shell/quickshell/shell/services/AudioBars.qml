pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/menupoll.js" as MenuPoll

// playback spectrum for the pill: the bar's music widget and its card both draw
// from this one cava feed (the PipeWire playback monitor, 40 bands / 30fps), so
// one analyser serves every music surface. `setActive` is owner-refcounted like
// PowerProfiles: cava runs only while a visible surface claims it. levels settle
// flat when frames stop arriving (system silent or a restart gap), so the bars
// fall to their rest slivers instead of freezing on the last peak.
Singleton {
    id: root

    property var activeOwners: []
    readonly property bool active: activeOwners.length > 0
    function setActive(owner, enabled) {
        activeOwners = MenuPoll.setOwnership(activeOwners, owner, enabled);
    }

    readonly property int bars: 40
    readonly property int fps: 30

    // 0..1 per band + mean energy across all bands.
    property var levels: root.flat()
    property real energy: 0
    property real lastReadMs: 0

    function flat() {
        var a = [];
        for (var i = 0; i < root.bars; i++)
            a.push(0);
        return a;
    }

    Process {
        id: cavaProc
        // playback spectrum via cava's native pipewire backend, source=auto (the default sink's monitor). the pulse backend can't connect here ("Connection terminated") even with pipewire-pulse up, and this path needs no pactl. exec so quickshell's SIGTERM reaches cava, leaving no orphaned analyser when the surface unloads.
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=\"${XDG_RUNTIME_DIR:-/tmp}/ryoku-cava-pill.conf\"; printf '%s\\n' '[general]' 'framerate = " + root.fps + "' 'bars = " + root.bars + "' '' '[input]' 'method = pipewire' 'source = auto' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 45' > \"$cfg\"; exec cava -p \"$cfg\""]
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

    // cava sleeps and stops emitting frames once playback idles, so settle back
    // to flat when no frame has arrived recently.
    Timer {
        interval: 120
        running: root.active
        repeat: true
        onTriggered: if (Date.now() - root.lastReadMs > 260) {
            root.levels = root.flat();
            root.energy = 0;
        }
    }

    onActiveChanged: {
        levels = flat();
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
