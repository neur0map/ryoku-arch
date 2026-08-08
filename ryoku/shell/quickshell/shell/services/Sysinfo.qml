pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../utils/menupoll.js" as MenuPoll

// Live computer stats for the quick-settings system monitor: CPU load from
// /proc/stat deltas, memory from /proc/meminfo, and a best-effort CPU package
// temperature scanned from hwmon. Polls on a 1.5s tick only while a visible
// owner claims it (setActive, owner-refcounted like AudioBars), so an unseen
// monitor costs nothing. A short CPU history feeds the card's sparkline.
Singleton {
    id: root

    property var owners: []
    readonly property bool active: root.owners.length > 0
    function setActive(owner, on) { root.owners = MenuPoll.setOwnership(root.owners, owner, on); }

    // 0..1 loads, GiB memory, degrees C.
    property real cpu: 0
    property real mem: 0
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real tempC: 0
    readonly property bool hasTemp: root.tempC > 0
    // recent CPU fractions (oldest .. newest) for the sparkline.
    property var cpuHistory: []

    property real _prevTotal: 0
    property real _prevIdle: 0

    // /proc/stat line 1: "cpu user nice system idle iowait irq softirq ...".
    // usage over the interval = 1 - idle_delta / total_delta.
    function _readStat(text) {
        var first = (text || "").split("\n")[0] || "";
        var p = first.trim().split(/\s+/);
        if (p[0] !== "cpu")
            return;
        var total = 0;
        for (var i = 1; i < p.length; i++)
            total += Number(p[i]) || 0;
        var idle = (Number(p[4]) || 0) + (Number(p[5]) || 0); // idle + iowait
        var dt = total - root._prevTotal;
        var di = idle - root._prevIdle;
        if (root._prevTotal > 0 && dt > 0) {
            var u = Math.max(0, Math.min(1, 1 - di / dt));
            root.cpu = u;
            var h = root.cpuHistory.slice();
            h.push(u);
            while (h.length > 48)
                h.shift();
            root.cpuHistory = h;
        }
        root._prevTotal = total;
        root._prevIdle = idle;
    }

    function _readMem(text) {
        var tot = 0, avail = 0;
        var lines = (text || "").split("\n");
        for (var i = 0; i < lines.length; i++) {
            var m = /^MemTotal:\s+(\d+)/.exec(lines[i]);
            if (m) { tot = Number(m[1]); continue; }
            m = /^MemAvailable:\s+(\d+)/.exec(lines[i]);
            if (m) avail = Number(m[1]);
        }
        if (tot > 0) {
            root.mem = Math.max(0, Math.min(1, (tot - avail) / tot));
            root.memTotalGiB = tot / 1048576;
            root.memUsedGiB = (tot - avail) / 1048576;
        }
    }

    // hwmon reports temp in millidegrees; degrees fall through unchanged.
    function _readTemp(text) {
        var v = parseInt((text || "").trim(), 10);
        if (!isNaN(v) && v > 0)
            root.tempC = v > 1000 ? v / 1000 : v;
    }

    FileView { id: statFile; path: "/proc/stat"; blockLoading: true; printErrors: false; onLoaded: root._readStat(statFile.text()) }
    FileView { id: memFile; path: "/proc/meminfo"; blockLoading: true; printErrors: false; onLoaded: root._readMem(memFile.text()) }

    // CPU package temperature: the first hwmon whose name is a known CPU sensor.
    Process {
        id: tempProc
        command: ["sh", "-c", "for d in /sys/class/hwmon/hwmon*; do n=$(cat \"$d/name\" 2>/dev/null); case \"$n\" in k10temp|zenpower|coretemp) cat \"$d/temp1_input\" 2>/dev/null && exit 0;; esac; done"]
        stdout: StdioCollector { onStreamFinished: root._readTemp(this.text) }
    }

    Timer {
        interval: 1500
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            memFile.reload();
            tempProc.running = false;
            tempProc.running = true;
        }
    }
    // drop the stale delta baseline on close so the next open measures a fresh
    // interval rather than one spanning the idle gap.
    onActiveChanged: if (!root.active) root._prevTotal = 0;
}
