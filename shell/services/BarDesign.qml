pragma Singleton

import QtQuick
import Quickshell
import Ryoku.Config

// RYOKU: resolves the active bar "design" — a declarative, swappable visual
// identity for the visible bar. The frame, wrappers, plugins and IPC are
// permanent shell infrastructure and are NOT part of a design; only the bar's
// template + entries (+ later token overlay/edge) change.
//
// Built-in designs below are Ryoku-owned data. Third-party / user designs are
// loaded from validated JSON (never executed) by the import command and merged
// into the same in-memory shape — they can never bring their own IPC, daemons
// or code into the shell. This is a global singleton (no per-screen context),
// so the per-screen entries decision lives in the bar template.
Singleton {
    id: root

    readonly property var builtins: ({
            "sidebar-left": {
                "name": "Sidebar (left)",
                "templateId": "sidebar-left"
            },
            "sidebar-compact": {
                "name": "Compact sidebar",
                "templateId": "sidebar-left",
                "entries": [
                    {
                        "id": "logo",
                        "enabled": true
                    },
                    {
                        "id": "workspaces",
                        "enabled": true
                    },
                    {
                        "id": "spacer",
                        "enabled": true
                    },
                    {
                        "id": "tray",
                        "enabled": true
                    },
                    {
                        "id": "clock",
                        "enabled": true
                    },
                    {
                        "id": "statusIcons",
                        "enabled": true
                    },
                    {
                        "id": "power",
                        "enabled": true
                    }
                ]
            },
            "top-notch": {
                "name": "Top Notch",
                "templateId": "top-notch",
                "edge": "top",
                "fillsEdge": false
            }
        })

    // Active design id, falling back to sidebar-left for unknown ids so a stale
    // or hand-typed bar.design can never blank the bar. Frozen at startup: switching
    // the design persists to config and restarts the shell, so the live value must
    // not change reactively. Otherwise the bar hot-swaps with stale geometry (a
    // visible glitch in the moment before the restart); the fresh process re-reads it.
    property string currentId: builtins[GlobalConfig.bar.design] ? GlobalConfig.bar.design : "sidebar-left"
    Component.onCompleted: currentId = currentId
    readonly property var current: builtins[currentId]
    readonly property string templateId: current.templateId ?? "sidebar-left"
    readonly property string edge: current.edge ?? "left"
    // Whether the bar uniformly thickens the frame border on its edge
    // (sidebar) or keeps the border thin and draws discrete notches (top-notch).
    readonly property bool fillsEdge: current.fillsEdge ?? true

    // Preset entries for the active design, or null when the design defers to
    // the user's own configured entries (sidebar-left).
    readonly property var presetEntries: currentId === "sidebar-left" ? null : (current.entries ?? null)

    // Settings selector model (NComboBox: {key, name}).
    readonly property var available: Object.keys(builtins).map(id => ({
                "key": id,
                "name": builtins[id].name
            }))
}
