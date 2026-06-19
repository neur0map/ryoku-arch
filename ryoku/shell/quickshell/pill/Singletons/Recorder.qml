pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property bool paused: false
    property int startedAt: 0
    property int elapsedSec: 0
    property real pulse: 1
    readonly property string elapsedText: fmt(elapsedSec)

    SequentialAnimation on pulse {
        running: root.active && !root.paused
        loops: Animation.Infinite
        NumberAnimation { to: 0.18; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
    }

    Process {
        id: poll
        command: ["sh", "-c", "PF=$HOME/.cache/qs_recording_state/wl_pid; PA=$HOME/.cache/qs_recording_state/paused; if [ -f \"$PF\" ] && kill -0 $(cat \"$PF\") 2>/dev/null; then [ -f \"$PA\" ] && echo paused || echo active; elif pgrep -x wf-recorder >/dev/null 2>&1 || pgrep -x gpu-screen-recorder >/dev/null 2>&1; then echo active; else echo off; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var state = text.trim();
                var nowActive = state === "active" || state === "paused";
                if (nowActive && !root.active) {
                    root.startedAt = Math.floor(Date.now() / 1000);
                    root.elapsedSec = 0;
                }
                if (!nowActive) {
                    root.startedAt = 0;
                    root.elapsedSec = 0;
                    root.pulse = 1;
                }
                root.active = nowActive;
                root.paused = state === "paused";
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    Timer {
        interval: 1000
        running: root.active && !root.paused
        repeat: true
        onTriggered: root.elapsedSec = Math.max(0, Math.floor(Date.now() / 1000) - root.startedAt)
    }

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var r = s % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
