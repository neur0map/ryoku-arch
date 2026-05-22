pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils

Singleton {
    id: root

    readonly property string configPath: `${Paths.home}/.config/hypr/hyprland.conf`
    readonly property string userPath: `${Paths.home}/.config/hypr/ryoku-user-binds.conf`

    property bool visible
    property bool loading
    property string status
    property string error
    property var entries: []

    function open(): void {
        visible = true;
        refresh();
    }

    function close(): void {
        visible = false;
    }

    function toggle(): void {
        visible ? close() : open();
    }

    function refresh(): void {
        if (listProc.running)
            return;

        loading = true;
        error = "";
        listProc.exec(["ryoku-keybinds", "list"]);
    }

    function load(data: string): void {
        try {
            entries = JSON.parse(data).filter(entry => entry && entry.combo);
            status = qsTr("%1 keybinds loaded").arg(entries.length);
            error = "";
        } catch (e) {
            error = qsTr("Could not read Hyprland keybinds");
            console.warn(`Keybind parse failed: ${e}`);
        }
    }

    function addBind(mods: string, key: string, dispatcher: string, arg: string, description: string): void {
        if (!key.trim() || !dispatcher.trim()) {
            error = qsTr("Key and action are required");
            return;
        }

        error = "";
        status = qsTr("Saving keybind");
        addProc.pending = true;
        addProc.succeeded = false;
        addProc.exec(["ryoku-keybinds", "add", "--mods", mods.trim(), "--key", key.trim(), "--dispatcher", dispatcher.trim(), "--arg", arg.trim(), "--description", description.trim()]);
    }

    Component.onCompleted: refresh()

    Connections {
        function onConfigReloaded(): void {
            root.refresh();
        }

        target: Hypr
    }

    FileView {
        path: root.configPath
        watchChanges: true
        onLoaded: root.refresh()
        onFileChanged: reload()
    }

    FileView {
        path: root.userPath
        watchChanges: true
        onLoaded: root.refresh()
        onFileChanged: reload()
    }

    Process {
        id: listProc

        stdout: StdioCollector {
            onStreamFinished: root.load(text)
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.error = text.trim();
            }
        }

        onRunningChanged: {
            if (!running)
                root.loading = false;
        }
    }

    Process {
        id: addProc

        property bool pending
        property bool succeeded

        stdout: StdioCollector {
            onStreamFinished: {
                addProc.succeeded = text.trim() === "ok";
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                if (text.trim())
                    root.error = text.trim();
            }
        }

        onRunningChanged: {
            if (running || !pending)
                return;

            pending = false;
            if (succeeded) {
                root.status = qsTr("Keybind saved");
                root.refresh();
            } else if (!root.error) {
                root.error = qsTr("Could not save keybind");
            }
        }
    }

    IpcHandler {
        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }

        function toggle(): void {
            root.toggle();
        }

        function list(): string {
            return JSON.stringify(root.entries);
        }

        function add(mods: string, key: string, dispatcher: string, arg: string, description: string): void {
            root.addBind(mods, key, dispatcher, arg, description);
        }

        target: "keybinds"
    }
}
