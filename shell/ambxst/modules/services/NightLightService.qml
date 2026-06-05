pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool active: StateService.get("nightLight", false)
    
    property Process wlsunsetProcess: Process {
        command: ["wlsunset", "-t", "4499", "-T", "4500"]
        running: false
        stdout: SplitParser {
            onRead: (data) => {
                if (data) {
                    root.active = true
                }
            }
        }
        onStarted: {
            root.active = true
        }
        onExited: (code) => {
            root.active = false
        }
    }
    
    property Process killProcess: Process {
        command: ["pkill", "wlsunset"]
        running: false
        onExited: (code) => {
            root.active = false
        }
    }
    
    property Process checkRunningProcess: Process {
        command: ["pgrep", "wlsunset"]
        running: false
        onExited: (code) => {
            const isRunning = code === 0
            
            if (root.active && !isRunning) {
                console.log("NightLightService: Starting wlsunset (state was active but not running)")
                wlsunsetProcess.running = true
            } 
            else if (!root.active && isRunning) {
                console.log("NightLightService: Stopping wlsunset (state was inactive but running)")
                killProcess.running = true
            }
        }
    }

    function toggle() {
        if (active) {
            killProcess.running = true
        } else {
            wlsunsetProcess.running = true
        }
    }
    
    function syncState() {
        checkRunningProcess.running = true
    }

    onActiveChanged: {
        if (StateService.initialized) {
            StateService.set("nightLight", active);
        }
    }

    Connections {
        target: StateService
        function onStateLoaded() {
            root.active = StateService.get("nightLight", false);
            root.syncState();
        }
    }

    Timer {
        interval: 100
        running: true
        repeat: false
        onTriggered: {
            if (StateService.initialized) {
                root.active = StateService.get("nightLight", false);
                root.syncState();
            }
        }
    }
}
