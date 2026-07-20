pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io
import Ryoku.Ui.Singletons

// Live input level: one ink bar (mean energy) and a peak tick, fed by a small
// cava instance on the default source, running only while the widget shows.
Item {
    id: meter

    property bool active: false
    property real level: 0
    property real peak: 0

    Process {
        id: cavaProc
        // input spectrum straight off the default source; exec so quickshell's
        // SIGTERM reaps cava when the widget unloads (the visualizer's rule).
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=\"${XDG_RUNTIME_DIR:-/tmp}/ryoku-cava-miclevel.conf\"; printf '%s\\n' '[general]' 'framerate = 20' 'bars = 12' '' '[input]' 'method = pipewire' 'source = @DEFAULT_SOURCE@' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'channels = mono' 'mono_option = average' > \"$cfg\"; exec cava -p \"$cfg\""]
        running: meter.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var parts = line.trim().split(/[;\s]+/);
                if (parts.length < 12)
                    return;
                var sum = 0;
                for (var i = 0; i < 12; i++)
                    sum += Math.max(0, Math.min(1, parseInt(parts[i]) / 100 || 0));
                meter.level = sum / 12;
                meter.peak = Math.max(meter.peak * 0.96, meter.level);
                meter.lastReadMs = Date.now();
            }
        }
        onExited: if (meter.active) restart.restart()
    }
    Timer { id: restart; interval: 1200; onTriggered: if (meter.active && !cavaProc.running) cavaProc.running = true }
    // flatline when frames stop (muted mic, cava restart gap).
    property real lastReadMs: 0
    Timer {
        interval: 150
        running: meter.active
        repeat: true
        onTriggered: if (Date.now() - meter.lastReadMs > 400) {
            meter.level = 0;
            meter.peak = Math.max(0, meter.peak * 0.9);
        }
    }
    onActiveChanged: { level = 0; peak = 0; }

    Rectangle { anchors.fill: parent; color: Tokens.paperLift; border { width: Tokens.border; color: Tokens.lineSoft } }
    Rectangle {
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: Tokens.border }
        width: (parent.width - Tokens.border * 2) * Math.min(1, meter.level)
        color: Tokens.ink
        opacity: 0.7
        Behavior on width { NumberAnimation { duration: 80 } }
    }
    Rectangle {
        x: Tokens.border + (parent.width - Tokens.border * 2) * Math.min(1, meter.peak)
        width: Tokens.border * 2
        anchors { top: parent.top; bottom: parent.bottom; margins: Tokens.border }
        color: Tokens.sun
    }
}
