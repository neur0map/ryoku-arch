import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "lib/fuzzy.js" as Fuzzy

ShellRoot {
    id: root

    property string query: ""
    property var usage: ({})
    property bool shown: false
    property string targetMonitor: ""

    IpcHandler {
        target: "launcher"
        function show(mon: string): void {
            root.targetMonitor = mon;
            root.shown = true;
        }
        function hide(): void { root.shown = false; }
        function toggle(mon: string): void {
            if (root.shown) { root.shown = false; return; }
            root.targetMonitor = mon;
            root.shown = true;
        }
    }

    FileView {
        id: usageStore
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/launcher-usage.json"
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = usageStore.text();
        try {
            root.usage = raw && raw.length ? JSON.parse(raw) : ({});
        } catch (e) {
            root.usage = ({});
        }
    }

    readonly property var allEntries: {
        var src = DesktopEntries.applications.values;
        var out = [];
        for (var i = 0; i < src.length; i++)
            if (src[i] && !src[i].noDisplay) out.push(src[i]);
        return out;
    }

    readonly property int totalCount: allEntries.length
    readonly property var results: Fuzzy.rank(allEntries, query, usage)

    function run(entry) {
        if (entry) {
            if (entry.id) {
                root.usage[entry.id] = (root.usage[entry.id] || 0) + 1;
                usageStore.setText(JSON.stringify(root.usage));
                usageStore.waitForJob();
            }
            entry.execute();
        }
        root.shown = false;
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            visible: root.shown && root.targetMonitor === modelData.name

            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            WlrLayershell.namespace: "launcher"

            anchors { top: true; left: true; right: true; bottom: true }

            MouseArea {
                anchors.fill: parent
                onClicked: root.shown = false
            }

            Launcher {
                id: launcher
                anchors.centerIn: parent

                entries: root.results
                total: root.totalCount

                onLaunch: (entry) => root.run(entry)
                onQuit: root.shown = false
            }

            Connections {
                target: launcher
                function onQueryChanged() {
                    root.query = launcher.query;
                    launcher.selectedIndex = 0;
                }
            }

            onVisibleChanged: {
                if (visible) {
                    launcher.query = "";
                    launcher.selectedIndex = 0;
                    launcher.focusField();
                }
            }
        }
    }
}
