import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common
import qs.modules.common.functions
Item {
    id: root

    property bool active: false
    property list<real> points: []
    readonly property string configPath: FileUtils.trimFileProtocol(Directories.cache) + "/cava_config.txt"
    readonly property string scriptPath: FileUtils.trimFileProtocol(Directories.scriptPath) + "/cava/generate_config.sh"

    onActiveChanged: {
        if (active) {
            stopDebounce.stop()
            if (cavaProc.running || configGen.running) return
            configGen.running = true
        } else {
            stopDebounce.restart()
        }
    }

    Timer {
        id: stopDebounce
        interval: 800
        repeat: false
        onTriggered: {
            if (!root.active) {
                configGen.running = false
                cavaProc.running = false
                root.points = []
            }
        }
    }
    Component.onDestruction: {
        cavaProc.running = false
    }

    Process {
        id: configGen
        running: false
        command: ["/usr/bin/bash", root.scriptPath, root.configPath]
        onExited: (code, status) => {
            if (code === 0 && root.active) {
                if (!cavaProc.running) {
                    cavaProc.running = true
                }
            }
        }
    }

    Process {
        id: cavaProc
        running: false
        command: ["cava", "-p", root.configPath]
        onRunningChanged: {
            if (!running) root.points = []
        }
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }
}
