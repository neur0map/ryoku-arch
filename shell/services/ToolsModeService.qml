pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Owns the toolsMode IpcHandler. Lives in a singleton so it registers
// exactly once even when multiple bar instances exist (multi-monitor) and
// even before the tools pill is mounted (the chicken-and-egg case).
Singleton {
    id: root

    IpcHandler {
        target: "toolsMode"
        function toggle(): void { GlobalStates.toolsModeOpen = !GlobalStates.toolsModeOpen }
        function open(): void   { GlobalStates.toolsModeOpen = true }
        function close(): void  { GlobalStates.toolsModeOpen = false }
    }
}
