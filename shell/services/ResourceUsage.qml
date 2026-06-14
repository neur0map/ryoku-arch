pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.modules.common

// Ryoku ResourceUsage: maps onto Ryoku's SystemUsage. Maintains the rolling history
// arrays the Resources graph reads. Sampling (and the SystemUsage poll ref) is held
// only while the overlay is open, so it never polls /proc in the background once the
// overlay closes.
Singleton {
    id: root

    readonly property int historyLength: 60

    readonly property int cpuTemp: Math.round(SystemUsage.cpuTemp)
    readonly property int gpuTemp: Math.round(SystemUsage.gpuTemp)
    readonly property real memoryUsed: SystemUsage.memUsed
    readonly property real swapUsed: 0

    readonly property string maxAvailableCpuString: "--"
    readonly property string maxAvailableGpuString: "100%"
    readonly property string maxAvailableMemoryString: kbToGbString(SystemUsage.memTotal)
    readonly property string maxAvailableSwapString: "--"

    property list<real> cpuUsageHistory: []
    property list<real> gpuUsageHistory: []
    property list<real> memoryUsageHistory: []
    property list<real> swapUsageHistory: []

    // Active only while the overlay is open. Acquire/release a SystemUsage ref so
    // its polling timer is idle whenever the overlay is closed.
    readonly property bool _active: GlobalStates.overlayOpen
    property bool _refHeld: false
    on_ActiveChanged: {
        if (root._active && !root._refHeld) {
            root._refHeld = true;
            SystemUsage.refCount++;
        } else if (!root._active && root._refHeld) {
            root._refHeld = false;
            SystemUsage.refCount--;
        }
    }

    // No-op: the Resources widget calls this on completion, but activity
    // is driven by overlay-open state above.
    function ensureRunning(): void {}

    function kbToGbString(kb: real): string {
        return (kb / (1024 * 1024)).toFixed(1) + " GB";
    }

    function _push(arr, v) {
        const next = [...arr, v];
        if (next.length > root.historyLength)
            next.shift();
        return next;
    }

    Timer {
        running: root._active
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.cpuUsageHistory = root._push(root.cpuUsageHistory, SystemUsage.cpuPerc);
            root.gpuUsageHistory = root._push(root.gpuUsageHistory, SystemUsage.gpuPerc);
            root.memoryUsageHistory = root._push(root.memoryUsageHistory, SystemUsage.memPerc);
            root.swapUsageHistory = root._push(root.swapUsageHistory, 0);
        }
    }
}
