import QtQuick
import Quickshell.Io

// Controls fans via nbfc-linux.
// Default mode assumes "auto" — set by hyprland exec-once at startup.
//
// Modes:
//   "quiet" → nbfc set -s 0
//   "auto"  → nbfc set -a
//   "max"   → nbfc set -s 100
//
// Commands wrapped in `timeout 5` to prevent hanging on unavailable sensors.
//
// Exposes:
//   string mode         — "quiet" | "auto" | "max"
//   bool   busy         — true while a command is in flight
//   function setMode(m)

QtObject {
    id: root

    property string mode: "auto"
    property bool   busy: false
    

    property var _proc: Process {
        command: []
        running: false
        onRunningChanged: if (!running) root.busy = false
    }

    function setMode(m) {
        if (root.busy) return
        root.mode = m
        root.busy = true

        if      (m === "quiet") _proc.command = ["sh", "-c", "timeout 5 nbfc set -s 30"]
        else if (m === "max")   _proc.command = ["sh", "-c", "timeout 5 nbfc set -s 100"]
        else                    _proc.command = ["sh", "-c", "timeout 5 nbfc set -a"]

        _proc.running = false
        _proc.running = true
    }
}