pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property int startedAt: 0
    property int elapsedSec: 0
    readonly property string elapsedText: fmt(elapsedSec)

    Process {
        id: poll
        command: ["sh", "-c", "pactl list source-outputs 2>/dev/null | grep -Eiq 'application\\.(process\\.binary|name).*\"?(Discord|discord|vesktop|Vesktop|WebCord)' && echo 1 || echo 0"]
        stdout: StdioCollector {
            onStreamFinished: {
                var nowActive = text.trim() === "1";
                if (nowActive && !root.active) {
                    root.startedAt = Math.floor(Date.now() / 1000);
                    root.elapsedSec = 0;
                }
                if (!nowActive) {
                    root.startedAt = 0;
                    root.elapsedSec = 0;
                }
                root.active = nowActive;
            }
        }
    }

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    Timer {
        interval: 1000
        running: root.active
        repeat: true
        onTriggered: root.elapsedSec = Math.max(0, Math.floor(Date.now() / 1000) - root.startedAt)
    }

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var r = s % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
