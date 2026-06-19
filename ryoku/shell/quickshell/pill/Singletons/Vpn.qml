pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: false
    property string interfaceName: ""
    property bool badgeVisible: false
    property bool badgeConnect: true

    onActiveChanged: {
        badgeConnect = active;
        badgeVisible = true;
        badgeTimer.restart();
    }

    Process {
        id: poll
        command: ["sh", "-c", "ip link show up type wireguard 2>/dev/null | sed -nE 's/^[0-9]+: ([^:@]+):.*/\\1/p' | head -n 1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var name = text.trim();
                root.interfaceName = name;
                root.active = name.length > 0;
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
        id: badgeTimer
        interval: 4000
        onTriggered: root.badgeVisible = false
    }
}
