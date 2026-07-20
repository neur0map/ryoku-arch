pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui.Singletons

// The playback spectrum as a ghost behind the EQ faders: twenty faint ink
// bars, 20fps, running only while the panel is visible and audio plays. The
// cava plumbing mirrors visualizer/Singletons/Spectrum.qml at reduced rate.
Item {
    id: ghost

    property bool active: false
    property var levels: []

    Process {
        id: cavaProc
        // playback spectrum via cava's native pipewire backend (source=auto is
        // the default sink's monitor); exec so quickshell's SIGTERM reaps cava
        // when the panel hides. Mirrors the visualizer's Spectrum.qml.
        command: ["sh", "-c", "command -v cava >/dev/null 2>&1 || exit 0; cfg=\"${XDG_RUNTIME_DIR:-/tmp}/ryoku-cava-ryolayer.conf\"; printf '%s\\n' '[general]' 'framerate = 20' 'bars = 20' '' '[input]' 'method = pipewire' 'source = auto' '' '[output]' 'method = raw' 'raw_target = /dev/stdout' 'data_format = ascii' 'ascii_max_range = 100' 'channels = mono' 'mono_option = average' '' '[smoothing]' 'noise_reduction = 45' > \"$cfg\"; exec cava -p \"$cfg\""]
        running: ghost.active
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: (line) => {
                var parts = line.trim().split(/[;\s]+/);
                if (parts.length < 20)
                    return;
                var out = [];
                for (var i = 0; i < 20; i++)
                    out.push(Math.max(0, Math.min(1, parseInt(parts[i]) / 100 || 0)));
                ghost.levels = out;
                ghost.lastReadMs = Date.now();
            }
        }
        onExited: if (ghost.active) restart.restart()
    }
    Timer { id: restart; interval: 1200; onTriggered: if (ghost.active && !cavaProc.running) cavaProc.running = true }
    // settle to a flat rest when frames stop, so the ghost never freezes.
    property real lastReadMs: 0
    Timer {
        interval: 150
        running: ghost.active
        repeat: true
        onTriggered: if (Date.now() - ghost.lastReadMs > 400) ghost.levels = []
    }
    onActiveChanged: levels = []

    Row {
        anchors.fill: parent
        spacing: (width - 20 * barW) / 19
        readonly property real barW: Math.max(2, width / 32)
        Repeater {
            model: 20
            delegate: Rectangle {
                required property int index
                width: parent.barW
                height: Math.max(2, (ghost.levels[index] || 0) * ghost.height)
                anchors.bottom: parent.bottom
                color: Tokens.ink
                opacity: 0.14
            }
        }
    }
}
