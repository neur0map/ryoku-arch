pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The focused workspace id, made reliable against Ryoku's Hyprland fork.
//
// Quickshell 0.3.0 cannot parse the fork's workspace resync (see Fullscreen.qml),
// so Hyprland.focusedWorkspace stays null on a fresh instance until the first
// live focus event. A bar that reads focusedWorkspace directly then falls back to
// an invalid id, and the workspace strip's base math renders those as bogus
// numbers (-1 -> "9", 0 -> "10"). Seed the truth from hyprctl, keep re-seeding
// while the live focus is still missing, and prefer focusedWorkspace once it exists.
Singleton {
    id: root

    property int probedId: -1
    readonly property int activeId: Hyprland.focusedWorkspace
        ? Hyprland.focusedWorkspace.id
        : (probedId >= 1 ? probedId : 1)

    function probe() { proc.running = true; }

    Process {
        id: proc
        command: ["hyprctl", "activeworkspace", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { root.probedId = JSON.parse(this.text).id; } catch (e) {}
            }
        }
    }

    // while the live focus is still null, re-seed on any workspace/monitor event
    // so a switch made before quickshell learns the focus is still reflected.
    readonly property var watched: ({
        workspace: true, workspacev2: true,
        focusedmon: true, focusedmonv2: true,
        moveworkspace: true, moveworkspacev2: true,
        createworkspace: true, createworkspacev2: true,
        destroyworkspace: true, destroyworkspacev2: true
    })
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!Hyprland.focusedWorkspace && root.watched[event.name])
                Qt.callLater(root.probe);
        }
    }

    Component.onCompleted: root.probe()
}
