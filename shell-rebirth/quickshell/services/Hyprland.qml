pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Singleton {
    id: root
    signal stateChanged()
    readonly property var toplevels: Hyprland.toplevels
    readonly property var workspaces: Hyprland.workspaces
    readonly property var monitors: Hyprland.monitors
    readonly property Toplevel activeToplevel: ToplevelManager.activeToplevel
    readonly property HyprlandWorkspace focusedWorkspace: Hyprland.focusedWorkspace
    readonly property HyprlandMonitor focusedMonitor: Hyprland.focusedMonitor
    readonly property int focusedWorkspaceId: focusedWorkspace?.id ?? 1
    property real screenW: focusedMonitor ? focusedMonitor.width : 0
    property real screenH: focusedMonitor ? focusedMonitor.height : 0
    property real screenScale: focusedMonitor ? focusedMonitor.scale : 1

    // parsed hyprctl data, defaults are empty
    property var windowList: []
    property var windowByAddress: ({})
    property var addresses: []
    property var layers: ({})
    property var monitorsInfo: []
    property var workspacesInfo: []
    property var workspaceById: ({})
    property var workspaceIds: []
    property var activeWorkspaceInfo: null
    property string keyboardLayout: "?"

    // dispatch a command to Hyprland, no-op if not running
    function dispatch(request: string): void {
        Hyprland.dispatch(request)
    }

    // switch workspace safely
    function changeWorkspace(targetWorkspaceId) {
        root.dispatch("workspace " + targetWorkspaceId)
    }

    // find most recently focused window in a workspace
    function focusedWindowForWorkspace(workspaceId) {
        const wsWindows = root.windowList.filter(w => w.workspace.id === workspaceId)
        if (wsWindows.length === 0) return null
        return wsWindows.reduce((best, win) => {
            const bestFocus = best?.focusHistoryID ?? Infinity
            const winFocus = win?.focusHistoryID ?? Infinity
            return winFocus < bestFocus ? win : best
        }, null)
    }

    // check if a workspace has any windows
    function isWorkspaceOccupied(id: int): bool {
        return Hyprland.workspaces.values.find(w => w?.id === id)?.lastIpcObject.windows > 0 || false
    }

    // update all hyprctl processes
    function updateAll() {
        getClients.running = true
        getLayers.running = true
        getMonitors.running = true
        getWorkspaces.running = true
        getActiveWorkspace.running = true
    }

    // largest window in a workspace
    function biggestWindowForWorkspace(workspaceId) {
        const windowsInThisWorkspace = root.windowList.filter(w => w.workspace.id === workspaceId)
        return windowsInThisWorkspace.reduce((maxWin, win) => {
            const maxArea = (maxWin?.size?.[0] ?? 0) * (maxWin?.size?.[1] ?? 0)
            const winArea = (win?.size?.[0] ?? 0) * (win?.size?.[1] ?? 0)
            return winArea > maxArea ? win : maxWin
        }, null)
    }

    // refresh keyboard layout
    function refreshKeyboardLayout() {
        hyprctlDevices.running = true
    }

    // only create hyprctl processes if Hyprland is running
    Component.onCompleted: {
            updateAll()
            refreshKeyboardLayout()
    }

    // process to get keyboard layout
    Process {
        id: hyprctlDevices
        running: false
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const devices = JSON.parse(this.text)
                    const keyboard = devices.keyboards.find(k => k.main) || devices.keyboards[0]
                    root.keyboardLayout = keyboard?.active_keymap?.toUpperCase()?.slice(0, 2) ?? "?"
                } catch (err) {
                    console.error("Failed to parse keyboard layout:", err)
                    root.keyboardLayout = "?"
                }
            }
        }
    }

    Process {
        id: getClients
        running: false
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.windowList = JSON.parse(this.text)
                    let tempWinByAddress = {}
                    for (let win of root.windowList) tempWinByAddress[win.address] = win
                    root.windowByAddress = tempWinByAddress
                    root.addresses = root.windowList.map(w => w.address)
                } catch (e) {
                    console.error("Failed to parse clients:", e)
                }
            }
        }
    }

    Process {
        id: getMonitors
        running: false
        command: ["hyprctl", "monitors", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.monitorsInfo = JSON.parse(this.text) }
                catch (e) { console.error("Failed to parse monitors:", e) }
            }
        }
    }

    Process {
        id: getLayers
        running: false
        command: ["hyprctl", "layers", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.layers = JSON.parse(this.text) }
                catch (e) { console.error("Failed to parse layers:", e) }
            }
        }
    }

    Process {
        id: getWorkspaces
        running: false
        command: ["hyprctl", "workspaces", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.workspacesInfo = JSON.parse(this.text)
                    let map = {}
                    for (let ws of root.workspacesInfo) map[ws.id] = ws
                    root.workspaceById = map
                    root.workspaceIds = root.workspacesInfo.map(ws => ws.id)
                } catch (e) { console.error("Failed to parse workspaces:", e) }
            }
        }
    }

    Process {
        id: getActiveWorkspace
        running: false
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.activeWorkspaceInfo = JSON.parse(this.text) }
                catch (e) { console.error("Failed to parse active workspace:", e) }
            }
        }
    }

    // only connect to Hyprland events if running
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if ( event.name.endsWith("v2")) return

            if (event.name.includes("activelayout"))
                refreshKeyboardLayout()
            else if (event.name.includes("mon"))
                Hyprland.refreshMonitors()
            else if (event.name.includes("workspace") || event.name.includes("window"))
                Hyprland.refreshWorkspaces()
            else
                Hyprland.refreshToplevels()

            updateAll()
            root.stateChanged()
        }
    }
}