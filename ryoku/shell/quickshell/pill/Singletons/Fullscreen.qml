pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Which workspaces currently hold a fullscreen window, read straight from
// hyprctl so the shell can retract its frame and bar over fullscreen content.
//
// quickshell 0.3.0 keeps HyprlandWorkspace.hasFullscreen fresh two ways: the
// raw `fullscreen` event, which only marks the *focused* workspace, and a
// j/workspaces resync fired right after to correct every other case (a second
// monitor, a fullscreen window dragged between workspaces). Ryoku's Hyprland
// fork answers that request socket in a shape quickshell cannot parse, so the
// resync yields nothing and only the focused monitor ever learns a window went
// fullscreen. On a single panel focused and active coincide and it looks fine;
// on a second monitor the frame and bar stay drawn over the fullscreen window.
// Probe j/workspaces ourselves and key it by workspace id; the pill and the OSD
// look up their monitor's active workspace here instead of trusting the
// resync-derived property.
Singleton {
    id: root

    // workspace id -> that workspace holds a fullscreen window.
    property var byWs: ({})

    function probe() { proc.running = true; }

    Process {
        id: proc
        command: ["hyprctl", "-j", "workspaces"]
        stdout: StdioCollector {
            onStreamFinished: {
                var map = {};
                try {
                    var arr = JSON.parse(this.text || "[]");
                    for (var i = 0; i < arr.length; i++)
                        map[arr[i].id] = arr[i].hasfullscreen === true;
                } catch (e) {}
                root.byWs = map;
            }
        }
    }

    // re-probe when fullscreen toggles or a monitor's visible workspace
    // changes; Qt.callLater folds an event burst into one hyprctl call.
    readonly property var watched: ({
        fullscreen: true,
        workspace: true, workspacev2: true,
        focusedmon: true, focusedmonv2: true,
        moveworkspace: true, moveworkspacev2: true,
        openwindow: true, closewindow: true,
        monitoradded: true, monitoraddedv2: true, monitorremoved: true
    })

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.watched[event.name])
                Qt.callLater(root.probe);
        }
    }

    Component.onCompleted: root.probe()
}
