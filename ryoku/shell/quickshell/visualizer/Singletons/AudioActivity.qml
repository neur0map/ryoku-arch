pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Whether any application is actively playing audio. The visualiser uses this to
// run cava only when there is sound to show, instead of spinning it at the
// configured framerate around the clock. Reads the native pipewire graph via
// pw-dump (pactl is unreliable here: its pulse compat drops the connection, so
// the old probe always reported silence and the analyser never woke). Defaults
// to playing so a box without pw-dump/jq, or the window before the first probe,
// behaves exactly as before rather than going dark.
Singleton {
    id: root

    property bool playing: true

    Process {
        id: probe
        // active when any application output stream is in the running state.
        command: ["sh", "-c", "command -v pw-dump >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || { echo keep; exit 0; }; pw-dump 2>/dev/null | jq -e 'any(.[]; .info.props.\"media.class\" == \"Stream/Output/Audio\" and .info.state == \"running\")' >/dev/null 2>&1 && echo on || echo off"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = text.trim();
                if (t === "on")
                    root.playing = true;
                else if (t === "off")
                    root.playing = false;
                // "keep" means no pw-dump/jq: leave playing untouched (true).
            }
        }
    }

    // pw-mon fires thousands of events a second during playback (per-frame param
    // updates), so an event-driven wake would starve a debounce; a short poll
    // keeps `playing` current instead, cheap next to the 60fps render the
    // spectrum already runs.
    Timer {
        interval: 700
        running: true
        repeat: true
        onTriggered: probe.running = true
    }

    Component.onCompleted: probe.running = true
}
