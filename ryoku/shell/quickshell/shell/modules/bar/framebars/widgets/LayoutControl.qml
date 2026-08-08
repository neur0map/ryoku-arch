pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import shell.services
import "../lib/providers.js" as Providers

// Resolves the active workspace's tiled layout and applies a chosen layout to it.
// Event driven: the layout is re-read only on the Hyprland events that can change
// it (mirroring the reference re-subscribe on WorkspaceChanged), never on a
// timer. `processCommand`, `stopped()` and `stop()` are part of the API the menu
// and its integration harness rely on.
Item {
    id: root

    property bool active: false
    readonly property var layouts: Providers.layouts
    property string current: ""
    property var processCommand: ["sh", "-c", "hyprctl -j activeworkspace 2>/dev/null | jq -r '.tiledLayout // .layout // empty'"]
    signal stopped()

    // The Hyprland events that can change the active workspace's layout.
    readonly property var watched: ({
        workspace: true, workspacev2: true,
        focusedmon: true, focusedmonv2: true,
        activelayout: true
    })

    onActiveChanged: {
        if (active)
            refresh();
        else
            stop();
    }
    Component.onCompleted: refresh()
    Component.onDestruction: stop()

    function refresh() {
        if (active)
            layoutProc.running = true;
    }

    // SetLayout: apply a per-workspace layout rule to this workspace, then
    // optimistically set current (tiled_layout does not update on an empty
    // workspace). Contract 03 sec 4.5.
    function choose(layout) {
        if (!active || !layouts.includes(layout))
            return;
        Quickshell.execDetached(["hyprctl", "eval",
            'hl.workspace_rule({ workspace = "' + Workspaces.activeId + '", layout = "' + layout + '" })']);
        current = layout;
    }

    function stop() {
        if (layoutProc.running) {
            layoutProc.running = false;
            stopped();
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (root.active && root.watched[event.name])
                Qt.callLater(root.refresh);
        }
    }

    Process {
        id: layoutProc
        command: root.processCommand
        stdout: StdioCollector {
            onStreamFinished: root.current = Providers.parseLayouts(this.text)[0] || ""
        }
    }
}
