pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions

Singleton {
    id: root

    property bool inhibit: false
    property bool _idleInhibitorAllowed: false
    readonly property int screenOffTimeout: Config.options?.idle?.screenOffTimeout ?? 300
    readonly property int lockTimeout: Config.options?.idle?.lockTimeout ?? 600
    readonly property int suspendTimeout: Config.options?.idle?.suspendTimeout ?? 0

    onScreenOffTimeoutChanged: _syncIdleDaemon()
    onLockTimeoutChanged: _syncIdleDaemon()
    onSuspendTimeoutChanged: _syncIdleDaemon()
    onInhibitChanged: _syncIdleDaemon()

    function toggleInhibit(active = null): void {
        if (active !== null) {
            inhibit = active;
        } else {
            inhibit = !inhibit;
        }
        Persistent.states.idle.inhibit = inhibit;
    }

    function _syncIdleDaemon() {
        _idleInhibitorAllowed = false
        _stopLegacySwayidle()
        _stopStaleRyokuInhibitors()
        _ensureHypridleDelayed.restart()
        if (inhibit) _startIdleInhibitorDelayed.restart()
    }

    function _stopLegacySwayidle() {
        Quickshell.execDetached(["/usr/bin/pkill", "-x", "swayidle"])
    }

    function _stopStaleRyokuInhibitors() {
        Quickshell.execDetached(["/usr/bin/pkill", "-f", "^/usr/bin/systemd-inhibit --what=idle --who=Ryoku .*Ryoku caffeine mode"])
    }

    function _ensureHypridle() {
        console.log("[Idle] Ensuring hypridle is running")
        Quickshell.execDetached(["/usr/bin/systemctl", "--user", "start", "hypridle.service"])
    }

    Timer {
        id: _ensureHypridleDelayed
        interval: 200
        onTriggered: root._ensureHypridle()
    }

    Timer {
        id: _startIdleInhibitorDelayed
        interval: 150
        onTriggered: {
            if (root.inhibit)
                root._idleInhibitorAllowed = true
        }
    }

    Process {
        id: _idleInhibitor
        running: root.inhibit && root._idleInhibitorAllowed
        command: ["/usr/bin/systemd-inhibit", "--what=idle", "--who=Ryoku", "--why=Ryoku caffeine mode", "/usr/bin/sleep", "infinity"]
        onExited: (exitCode, exitStatus) => {
            if (root.inhibit && root._idleInhibitorAllowed)
                console.warn("[Idle] systemd idle inhibitor exited unexpectedly:", exitCode, exitStatus)
        }
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) root._syncIdleDaemon()
        }
    }

    Connections {
        target: Persistent
        function onReadyChanged() {
            if (Persistent.ready && Persistent.states?.idle?.inhibit)
                root.inhibit = true
        }
    }

    Component.onDestruction: {
        _idleInhibitorAllowed = false
        _stopLegacySwayidle()
        _stopStaleRyokuInhibitors()
    }
}
