pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string sockPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-shell.sock"
    property var frame: ({ status: "loading", region: "", source: "", days: [] })
    readonly property string status: frame.status || "loading"
    readonly property string region: frame.region || ""
    readonly property string errorText: frame.error || ""
    readonly property var days: Array.isArray(frame.days) ? frame.days : []
    property var byDate: ({})
    property string requestedRegion: ""
    property var requestedYears: []

    function forDate(key) { return root.byDate[key] || []; }
    function hasDate(key) { return root.forDate(key).length > 0; }

    function configure(region, years) {
        const normalizedYears = (years || []).slice().sort();
        const signature = normalizedYears.join(",");
        if (root.requestedRegion === region && root.requestedYears.join(",") === signature)
            return;
        root.requestedRegion = region;
        root.requestedYears = normalizedYears;
        root.send("calendar.configure", { region: region, years: normalizedYears });
    }

    function apply(line) {
        try {
            const next = JSON.parse(line);
            if (!Array.isArray(next.days))
                next.days = [];
            const index = {};
            for (const holiday of next.days) {
                if (!holiday || typeof holiday.date !== "string")
                    continue;
                if (!index[holiday.date])
                    index[holiday.date] = [];
                index[holiday.date].push(holiday);
            }
            root.frame = next;
            root.byDate = index;
        } catch (e) {
        }
    }

    function send(method, args) {
        ctl.queued += "call " + method + " " + JSON.stringify(args) + "\n";
        if (ctl.connected)
            ctl.flushQueued();
        else
            ctl.connected = true;
    }

    Socket {
        id: sub
        path: root.sockPath
        parser: SplitParser { onRead: line => root.apply(line) }
        Component.onCompleted: connected = true
        onConnectionStateChanged: {
            if (connected) {
                write("subscribe calendar\n");
                flush();
            } else {
                retry.restart();
            }
        }
    }

    Timer {
        id: retry
        interval: 2000
        onTriggered: if (!sub.connected) sub.connected = true
    }

    Socket {
        id: ctl
        path: root.sockPath
        property string queued: ""

        function flushQueued() {
            if (queued.length === 0)
                return;
            write(queued);
            flush();
            queued = "";
        }

        onConnectionStateChanged: if (connected) flushQueued()
    }
}
