pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Live system vitals for the ryolayer system monitor. One Timer drives every
// sample; nothing runs while `active` is false, so a closed layer with nothing
// pinned costs zero. Kernel-native reads (/proc, /sys/class/hwmon) resolve
// their paths once by hwmon `name` (indices renumber across boots), the disk
// used/size comes from one df, and the NVIDIA dGPU is only ever queried with
// nvidia-smi while its PCI runtime_status reads "active": polling a
// runtime-suspended laptop dGPU wakes it and burns battery, so the asleep
// state is reported as-is and left alone. Absent sensors report -1 (empty
// array for cores); consumers omit the row rather than draw a sentinel.
Singleton {
    id: root

    property bool active: false

    // ── exposed vitals ───────────────────────────────────────────────────
    property int cpuLoad: 0
    property int cpuTemp: -1
    property var cores: []
    property real memUsed: -1
    property real memTotal: -1
    property real swapUsed: -1
    property real swapTotal: -1
    property real diskUsed: -1
    property real diskTotal: -1
    property int diskTemp: -1
    property int igpuTemp: -1
    property int igpuLoad: -1
    property bool dgpuAwake: false
    property int dgpuTemp: -1
    property int dgpuLoad: -1
    property real dgpuVramUsed: -1
    property real dgpuVramTotal: -1
    property real load1: -1
    property real load5: -1
    property real load15: -1
    property string uptime: ""

    // ── resolved sensor paths (set once by the enumerator) ────────────────
    property string _cpuTempPath: ""
    property string _igpuTempPath: ""
    property string _igpuBusyPath: ""
    property string _nvmeTempPath: ""
    property string _dgpuStatusPath: ""
    property bool _resolved: false
    property bool _smiAvailable: false

    // previous /proc/stat aggregate + per-core samples, for the busy-fraction
    // delta between ticks.
    property real _prevIdle: 0
    property real _prevTotal: 0
    property var _prevCoreIdle: []
    property var _prevCoreTotal: []

    readonly property real _kib: 1024
    function _gib(kb) { return kb / _kib / _kib; }

    Timer {
        interval: 1500
        repeat: true
        running: root.active
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            loadFile.reload();
            uptimeFile.reload();
            if (root._cpuTempPath.length > 0) cpuTempFile.reload();
            if (root._igpuTempPath.length > 0) igpuTempFile.reload();
            if (root._igpuBusyPath.length > 0) igpuBusyFile.reload();
            if (root._nvmeTempPath.length > 0) nvmeTempFile.reload();
            if (!dfProc.running) dfProc.running = true;
            if (root._dgpuStatusPath.length > 0)
                dgpuStatusFile.reload();
            else
                root.dgpuAwake = false;
            // a suspended dGPU must never be woken: only touch nvidia-smi once
            // the runtime_status just read back "active".
            if (root._smiAvailable && root.dgpuAwake) {
                if (!smiProc.running) smiProc.running = true;
            } else {
                root.dgpuTemp = -1;
                root.dgpuLoad = -1;
                root.dgpuVramUsed = -1;
                root.dgpuVramTotal = -1;
            }
        }
    }

    // Resolve hwmon and the NVIDIA device once per activation by content, not
    // index: k10temp -> CPU Tctl, amdgpu -> iGPU edge temp + its device-dir
    // busy percent, nvme -> disk composite, and the NVIDIA display-class PCI
    // function's runtime_status (its audio function is a separate device).
    Process {
        id: resolveProc
        running: root.active && !root._resolved
        command: ["sh", "-c",
            "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); " +
            "case \"$n\" in " +
            "k10temp) echo \"cpuTemp=$d/temp1_input\";; " +
            "amdgpu) echo \"igpuTemp=$d/temp1_input\"; dev=$(readlink -f \"$d/device\" 2>/dev/null); [ -n \"$dev\" ] && echo \"igpuBusy=$dev/gpu_busy_percent\";; " +
            "nvme) echo \"nvmeTemp=$d/temp1_input\";; " +
            "esac; done; " +
            "for d in /sys/bus/pci/devices/*; do v=$(cat \"$d/vendor\" 2>/dev/null); c=$(cat \"$d/class\" 2>/dev/null); " +
            "[ \"$v\" = \"0x10de\" ] || continue; case \"$c\" in 0x0300*|0x0302*) echo \"dgpuStatus=$d/power/runtime_status\";; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var eq = lines[i].indexOf("=");
                    if (eq < 0) continue;
                    var k = lines[i].substring(0, eq);
                    var v = lines[i].substring(eq + 1).trim();
                    if (k === "cpuTemp") root._cpuTempPath = v;
                    else if (k === "igpuTemp") root._igpuTempPath = v;
                    else if (k === "igpuBusy") root._igpuBusyPath = v;
                    else if (k === "nvmeTemp") root._nvmeTempPath = v;
                    else if (k === "dgpuStatus") root._dgpuStatusPath = v;
                }
                root._resolved = true;
            }
        }
    }

    Process {
        id: smiAvailProc
        running: root.active
        command: ["sh", "-c", "command -v nvidia-smi >/dev/null 2>&1"]
        onExited: (code) => { root._smiAvailable = (code === 0); }
    }

    FileView {
        id: statFile
        path: "/proc/stat"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var lines = statFile.text().split("\n");
            var coreIdle = [];
            var coreTotal = [];
            var out = [];
            for (var li = 0; li < lines.length; li++) {
                var f = lines[li].trim().split(/\s+/);
                if (f.length < 8 || f[0].substring(0, 3) !== "cpu")
                    continue;
                var idle = Number(f[4]) + Number(f[5]);
                var total = 0;
                for (var i = 1; i < f.length; i++)
                    total += Number(f[i]);
                if (f[0] === "cpu") {
                    var dIdle = idle - root._prevIdle;
                    var dTotal = total - root._prevTotal;
                    if (root._prevTotal > 0 && dTotal > 0)
                        root.cpuLoad = Math.max(0, Math.min(100, Math.round(100 * (1 - dIdle / dTotal))));
                    root._prevIdle = idle;
                    root._prevTotal = total;
                } else {
                    var ci = Number(f[0].substring(3));
                    var pi = root._prevCoreIdle[ci] || 0;
                    var pt = root._prevCoreTotal[ci] || 0;
                    var dci = idle - pi;
                    var dct = total - pt;
                    if (pt > 0 && dct > 0)
                        out[ci] = Math.max(0, Math.min(100, Math.round(100 * (1 - dci / dct))));
                    else
                        out[ci] = 0;
                    coreIdle[ci] = idle;
                    coreTotal[ci] = total;
                }
            }
            root._prevCoreIdle = coreIdle;
            root._prevCoreTotal = coreTotal;
            if (root._prevCoreTotal.length > 0 && out.length > 0)
                root.cores = out;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var t = memFile.text();
            var mt = Number((t.match(/MemTotal:\s+(\d+)/) || [])[1] || 0);
            var ma = Number((t.match(/MemAvailable:\s+(\d+)/) || [])[1] || 0);
            var st = Number((t.match(/SwapTotal:\s+(\d+)/) || [])[1] || 0);
            var sf = Number((t.match(/SwapFree:\s+(\d+)/) || [])[1] || 0);
            if (mt > 0) {
                root.memTotal = root._gib(mt);
                root.memUsed = root._gib(mt - ma);
            }
            root.swapTotal = root._gib(st);
            root.swapUsed = root._gib(st - sf);
        }
    }

    FileView {
        id: loadFile
        path: "/proc/loadavg"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var f = (loadFile.text() || "").trim().split(/\s+/);
            if (f.length >= 3) {
                root.load1 = Number(f[0]);
                root.load5 = Number(f[1]);
                root.load15 = Number(f[2]);
            }
        }
    }

    FileView {
        id: uptimeFile
        path: "/proc/uptime"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var s = Number(((uptimeFile.text() || "").trim().split(/\s+/))[0] || 0);
            var d = Math.floor(s / 86400);
            var h = Math.floor((s % 86400) / 3600);
            var m = Math.floor((s % 3600) / 60);
            root.uptime = d > 0 ? (d + "d " + h + "h") : (h > 0 ? (h + "h " + m + "m") : (m + "m"));
        }
    }

    FileView {
        id: cpuTempFile
        path: root._cpuTempPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            var v = Number((cpuTempFile.text() || "").trim());
            root.cpuTemp = v > 0 ? Math.round(v / 1000) : -1;
        }
    }

    FileView {
        id: igpuTempFile
        path: root._igpuTempPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            var v = Number((igpuTempFile.text() || "").trim());
            root.igpuTemp = v > 0 ? Math.round(v / 1000) : -1;
        }
    }

    FileView {
        id: igpuBusyFile
        path: root._igpuBusyPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            var v = (igpuBusyFile.text() || "").trim();
            root.igpuLoad = v.length > 0 ? Math.max(0, Math.min(100, Number(v))) : -1;
        }
    }

    FileView {
        id: nvmeTempFile
        path: root._nvmeTempPath
        blockLoading: true
        printErrors: false
        onLoaded: {
            var v = Number((nvmeTempFile.text() || "").trim());
            root.diskTemp = v > 0 ? Math.round(v / 1000) : -1;
        }
    }

    FileView {
        id: dgpuStatusFile
        path: root._dgpuStatusPath
        blockLoading: true
        printErrors: false
        onLoaded: root.dgpuAwake = (dgpuStatusFile.text() || "").trim() === "active"
    }

    Process {
        id: dfProc
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = (this.text || "").trim().split("\n");
                if (lines.length < 2) return;
                var f = lines[lines.length - 1].trim().split(/\s+/);
                if (f.length < 2) return;
                root.diskUsed = Number(f[0]) / 1024 / 1024 / 1024;
                root.diskTotal = Number(f[1]) / 1024 / 1024 / 1024;
            }
        }
    }

    Process {
        id: smiProc
        command: ["nvidia-smi",
            "--query-gpu=temperature.gpu,utilization.gpu,memory.used,memory.total",
            "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                var f = (this.text || "").trim().split(",");
                if (f.length < 4) return;
                root.dgpuTemp = Math.round(Number(f[0]));
                root.dgpuLoad = Math.round(Number(f[1]));
                root.dgpuVramUsed = Number(f[2]) / 1024;
                root.dgpuVramTotal = Number(f[3]) / 1024;
            }
        }
    }
}
