pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// live system vitals for the Nacre bar's stats module: CPU% from /proc/stat
// deltas, RAM% from /proc/meminfo, temperature from a /sys thermal zone. all
// kernel-native, no per-tick subprocess (the zone path is resolved once). the
// poller runs only while `active` (a visible BarStats sets it), and keeps a
// short history for the resources popout sparklines.
Singleton {
    id: root

    property bool active: false
    property int cpu: 0
    property int mem: 0
    property int temp: 0
    property bool tempAvailable: false

    readonly property int histLen: 60
    property var cpuHistory: []
    property var memHistory: []
    property var tempHistory: []

    // previous /proc/stat aggregate sample, for the busy-fraction delta.
    property real _prevIdle: 0
    property real _prevTotal: 0
    property string _tempPath: ""

    function _push(arr, v) {
        var a = arr.slice();
        a.push(v);
        if (a.length > root.histLen)
            a.shift();
        return a;
    }

    Timer {
        interval: 2000
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            if (root._tempPath.length > 0)
                tempFile.reload();
        }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var line = statFile.text().split("\n")[0];
            var f = line.trim().split(/\s+/);
            if (f.length < 8 || f[0] !== "cpu")
                return;
            var idle = Number(f[4]) + Number(f[5]);
            var total = 0;
            for (var i = 1; i < f.length; i++)
                total += Number(f[i]);
            var dIdle = idle - root._prevIdle;
            var dTotal = total - root._prevTotal;
            var hadPrev = root._prevTotal > 0;
            root._prevIdle = idle;
            root._prevTotal = total;
            if (hadPrev && dTotal > 0) {
                root.cpu = Math.max(0, Math.min(100, Math.round(100 * (1 - dIdle / dTotal))));
                root.cpuHistory = root._push(root.cpuHistory, root.cpu);
            }
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var t = memFile.text();
            var total = Number((t.match(/MemTotal:\s+(\d+)/) || [])[1] || 0);
            var avail = Number((t.match(/MemAvailable:\s+(\d+)/) || [])[1] || 0);
            if (total > 0) {
                root.mem = Math.max(0, Math.min(100, Math.round(100 * (total - avail) / total)));
                root.memHistory = root._push(root.memHistory, root.mem);
            }
        }
    }

    // resolve a cpu-ish thermal zone once (types vary by machine), then poll it.
    Process {
        id: tempResolve
        running: root.active && root._tempPath.length === 0
        command: ["sh", "-c",
            "for d in /sys/class/thermal/thermal_zone*; do " +
            "t=$(cat \"$d/type\" 2>/dev/null); " +
            "case \"$t\" in *pkg*|*x86*|*cpu*|*coretemp*|*k10*|*acpitz*) echo \"$d/temp\"; exit 0;; esac; done; " +
            "ls /sys/class/thermal/thermal_zone*/temp 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                var p = (this.text || "").trim();
                if (p.length > 0)
                    root._tempPath = p;
            }
        }
    }

    FileView {
        id: tempFile
        path: root._tempPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            var v = Number((tempFile.text() || "").trim());
            if (v > 0) {
                root.temp = Math.round(v / 1000);
                root.tempAvailable = true;
                root.tempHistory = root._push(root.tempHistory, root.temp);
            } else {
                root.tempAvailable = false;
            }
        }
    }
}
