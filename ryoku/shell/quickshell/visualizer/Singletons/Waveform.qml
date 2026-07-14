pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live playback waveform for the line style's oscilloscope. wavecap.py captures
// the default sink's monitor (PipeWire-native, since the Pulse path can't
// connect on this stack) and streams downsampled amplitude frames; here we
// parse them into `samples` (-1..1). runs only while the line style is active,
// and clears to a flat trace when frames stop (a silent sink suspends its
// monitor). wavecap.py is a single exec'd process, so quickshell's SIGTERM
// reaches it and it tears pw-record down with no orphan.
Singleton {
    id: root

    property bool active: false
    // per-frame waveform samples (-1..1); empty == no signal (draw flat).
    property var samples: []
    property real lastReadMs: 0

    readonly property string capScript: Qt.resolvedUrl("wavecap.py").toString().replace(/^file:\/\//, "")

    Process {
        id: cap
        command: ["python3", "-u", root.capScript]
        running: root.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => root.readWave(line)
        }
        onExited: if (root.active) restartTimer.restart()
    }

    // the capture exits if the default sink changes; bring it back.
    Timer {
        id: restartTimer
        interval: 1000
        onTriggered: if (root.active && !cap.running) cap.running = true
    }

    // clear to a flat trace when frames stop arriving (suspended monitor).
    Timer {
        interval: 120
        running: root.active
        repeat: true
        onTriggered: if (Date.now() - root.lastReadMs > 300 && root.samples.length > 0)
            root.samples = [];
    }

    onActiveChanged: {
        samples = [];
        if (active)
            lastReadMs = Date.now();
    }

    function readWave(line) {
        var t = line.trim();
        if (!t)
            return;
        var parts = t.split(/\s+/);
        if (parts.length < 8)
            return;
        var out = [];
        for (var i = 0; i < parts.length; i++) {
            var v = parseFloat(parts[i]);
            out.push(isNaN(v) ? 0 : v);
        }
        root.samples = out;
        root.lastReadMs = Date.now();
    }
}
