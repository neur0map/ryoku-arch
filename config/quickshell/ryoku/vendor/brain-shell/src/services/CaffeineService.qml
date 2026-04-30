pragma Singleton
import QtQuick
import Quickshell.Io

QtObject {
    id: root

    property bool active: false
    property bool busy: false
    property bool _refreshAgain: false
    property int _generation: 0
    property int _refreshGeneration: 0
    readonly property string _inhibitPattern: "systemd-inhibit.*--who=Ryoku.*--why=[C]affeine mode"

    function refresh() {
        if (_checkProc.running) {
            root._refreshAgain = true
            return
        }

        root._refreshAgain = false
        root._refreshGeneration = root._generation
        _checkProc.running = true
    }

    function start() {
        if (root.busy || root.active) return

        root._generation++
        root.busy = true
        root.active = true
        _startProc.running = false
        _startProc.running = true
    }

    function stop() {
        if (root.busy || !root.active) return

        root._generation++
        root.busy = true
        root.active = false
        _startProc.running = false
        _stopProc.running = false
        _stopProc.running = true
    }

    function toggle() {
        if (root.busy) return
        if (root.active) root.stop()
        else root.start()
    }

    property var _checkProc: Process {
        command: ["pgrep", "-f", root._inhibitPattern]
        running: false
        onExited: function(exitCode, exitStatus) {
            if (root._refreshGeneration === root._generation && !root.busy)
                root.active = exitCode === 0

            if (root._refreshAgain)
                root.refresh()
        }
    }

    property var _startProc: Process {
        command: [
            "systemd-inhibit",
            "--what=idle:sleep",
            "--who=Ryoku",
            "--why=Caffeine mode",
            "sleep",
            "infinity"
        ]
        running: false
        onRunningChanged: {
            if (running) {
                root.busy = false
                root.active = true
            } else if (root.active) {
                root.refresh()
            }
        }
    }

    property var _stopProc: Process {
        command: ["pkill", "-f", root._inhibitPattern]
        running: false
        onExited: function(exitCode, exitStatus) {
            root.busy = false
            root.refresh()
        }
    }

    Component.onCompleted: refresh()
}
