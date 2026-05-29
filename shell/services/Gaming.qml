pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// RYOKU: gaming overlay state + layout. Holds the overlay open/closed flag and a
// per-widget layout map ({enabled, pinned, x, y}) persisted to
// ~/.config/ryoku-shell/gaming-layout.json (debounced). Writes mirror CustomWidgets:
// UTF-8-safe base64 piped through `base64 -d` via Quickshell.execDetached.
// IPC: `gaming` (toggle/open/close/isOpen).
Singleton {
    id: root

    property bool open: false
    readonly property var widgetIds: ["crosshair", "stats", "recorder", "music", "gameMode"]
    property var layout: ({})
    readonly property string layoutPath: `${Paths.config}/gaming-layout.json`

    function _defaultRecord(id: string): var {
        return {
            "enabled": id === "crosshair",
            "pinned": false,
            "x": -1,
            "y": -1
        };
    }

    function record(id: string): var {
        return root.layout[id] ?? root._defaultRecord(id);
    }

    function setRecord(id: string, patch): void {
        const next = Object.assign({}, root.layout);
        next[id] = Object.assign({}, root.record(id), patch);
        root.layout = next;
        saveTimer.restart();
    }

    function isEnabled(id: string): bool {
        return root.record(id).enabled === true;
    }

    function isPinned(id: string): bool {
        return root.record(id).pinned === true;
    }

    function _b64(s: string): string {
        // UTF-8 safe base64 (handles unicode), matching CustomWidgets.
        return Qt.btoa(unescape(encodeURIComponent(s)));
    }

    function _save(): void {
        const b64 = root._b64(JSON.stringify(root.layout, null, 2));
        Quickshell.execDetached(["sh", "-c", `mkdir -p "${Paths.config}" && printf %s '${b64}' | base64 -d > "${root.layoutPath}"`]);
    }

    Component.onCompleted: layoutFile.reload()

    FileView {
        id: layoutFile

        path: root.layoutPath
        watchChanges: false
        printErrors: false

        onLoaded: {
            try {
                root.layout = JSON.parse(text()) || ({});
            } catch (e) {
                root.layout = ({});
            }
        }
        onLoadFailed: root.layout = ({})
    }

    Timer {
        id: saveTimer

        interval: 400
        onTriggered: root._save()
    }

    IpcHandler {
        function toggle(): void {
            root.open = !root.open;
        }

        function open(): void {
            root.open = true;
        }

        function close(): void {
            root.open = false;
        }

        function isOpen(): bool {
            return root.open;
        }

        target: "gaming"
    }
}
