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

    readonly property int cfgFramerate: Config.options?.appearance?.cava?.framerate ?? 60
    readonly property int cfgSensitivity: Config.options?.appearance?.cava?.sensitivity ?? 100
    readonly property int cfgBars: Config.options?.appearance?.cava?.bars ?? 0
    readonly property bool cfgStereo: Config.options?.appearance?.cava?.stereo ?? true
    readonly property int effectiveBars: cfgBars > 0 ? cfgBars : 50

    property bool _pendingRestart: false

    onCfgFramerateChanged: if (active) configRestart.restart()
    onCfgSensitivityChanged: if (active) configRestart.restart()
    onCfgBarsChanged: if (active) configRestart.restart()
    onCfgStereoChanged: if (active) configRestart.restart()

    Timer {
        id: configRestart
        interval: 300
        repeat: false
        onTriggered: {
            if (cavaProc.running) {
                root._pendingRestart = true
                cavaProc.running = false
            } else if (root.active && !configGen.running) {
                configGen.running = true
            }
        }
    }

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
                root._pendingRestart = false
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
        command: ["/usr/bin/bash", root.scriptPath, root.configPath,
            String(root.cfgFramerate), String(root.cfgSensitivity),
            String(root.effectiveBars), String(root.cfgStereo)]
        onExited: (code, status) => {
            if (code === 0 && root.active)
                cavaProc.running = true
        }
    }

    Process {
        id: cavaProc
        running: false
        command: ["cava", "-p", root.configPath]
        onRunningChanged: {
            if (!running) {
                root.points = []
                if (root._pendingRestart) {
                    root._pendingRestart = false
                    configGen.running = true
                }
            }
        }
        stdout: SplitParser {
            onRead: data => {
                root.points = data.split(";").map(p => parseFloat(p.trim())).filter(p => !isNaN(p))
            }
        }
    }
}
