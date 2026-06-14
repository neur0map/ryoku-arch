pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// RYOKU: floating sticky notes on the desktop. Each note is a JSON file under
// $XDG_RUNTIME_DIR/ryoku-shell/notes/ — that lives on tmpfs, so notes SURVIVE shell
// refreshes/restarts within a session but are CLEARED on logout/shutdown (plus the
// per-note corner trash deletes one immediately). Multiple notes are allowed.
Singleton {
    id: root

    readonly property string dir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/ryoku-shell/notes`

    // Array of per-note cfg objects (see noteComponent). Rebuilt on rescan.
    property var list: []

    function _b64(s: string): string {
        return Qt.btoa(unescape(encodeURIComponent(s)));
    }

    function _json(cfg): string {
        return JSON.stringify({
            "id": cfg.noteId,
            "text": cfg.text,
            "x": cfg.x,
            "y": cfg.y,
            "scale": cfg.scale,
            "locked": cfg.locked,
            "freePosition": cfg.freePosition,
            "position": cfg.position
        }, null, 2);
    }

    // Persist one note (text + geometry). Fire-and-forget; in-memory cfg is the source
    // of truth, so no rescan needed.
    function persist(cfg): void {
        const b64 = root._b64(root._json(cfg));
        Quickshell.execDetached(["sh", "-c", `mkdir -p "${root.dir}" && printf %s '${b64}' | base64 -d > "${root.dir}/${cfg.noteId}.json"`]);
    }

    function create(): void {
        const id = "note-" + Date.now();
        const cfg = {
            "id": id,
            "text": "",
            "x": 0,
            "y": 0,
            "scale": 1.0,
            "locked": false,
            "freePosition": false,
            "position": "center"
        };
        const b64 = root._b64(JSON.stringify(cfg, null, 2));
        opProc.command = ["sh", "-c", `mkdir -p "${root.dir}" && printf %s '${b64}' | base64 -d > "${root.dir}/${id}.json"`];
        opProc.running = true;
    }

    function remove(id: string): void {
        if (!id || id.indexOf("/") !== -1 || id === "." || id === "..")
            return;
        opProc.command = ["sh", "-c", `rm -f "${root.dir}/${id}.json"`];
        opProc.running = true;
    }

    function rescan(): void {
        if (!scanProc.running)
            scanProc.running = true;
    }

    function _rebuild(notes): void {
        for (let i = 0; i < root.list.length; i++) {
            if (root.list[i])
                root.list[i].destroy();
        }
        const out = [];
        for (let j = 0; j < notes.length; j++) {
            const n = notes[j] || {};
            if (!n.id)
                continue;
            const cfg = noteComponent.createObject(root, {
                "noteId": n.id,
                "text": n.text || "",
                "scale": (typeof n.scale === "number") ? n.scale : 1.0,
                "locked": n.locked === true,
                "freePosition": n.freePosition === true,
                "position": n.position || "center",
                "x": (typeof n.x === "number") ? n.x : 0,
                "y": (typeof n.y === "number") ? n.y : 0
            });
            if (cfg)
                out.push(cfg);
        }
        root.list = out;
    }

    Component.onCompleted: root.rescan()

    Component {
        id: noteComponent
        QtObject {
            property string noteId
            property string text: ""
            // Geometry/state consumed by DesktopWidget:
            property real x: 0
            property real y: 0
            property real scale: 1.0
            property bool locked: false
            property bool freePosition: false
            property string position: "center"
            function save(): void {
                root.persist(this);
            }
        }
    }

    Process {
        id: scanProc
        command: ["sh", "-c", `d="${root.dir}"; mkdir -p "$d"; printf '['; first=1; for m in "$d"/*.json; do [ -f "$m" ] || continue; if [ "$first" -eq 0 ]; then printf ','; fi; first=0; cat "$m"; done; printf ']'`]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._rebuild(JSON.parse(text));
                } catch (e) {
                    console.warn("Notes: failed to parse:", e);
                    root._rebuild([]);
                }
            }
        }
    }

    Process {
        id: opProc
        onExited: root.rescan()
    }
}
