pragma Singleton
import QtQuick
import Quickshell

/**
 * Update data for the Hub's Updates section.
 *
 * MOCK DATA, not wired to a backend yet: the versions, counts, and commit log
 * are placeholders so the section can be designed and reviewed. Wire to a
 * `ryoku-hub updates` subcommand (Go, reading how far the checkout is behind
 * upstream git) later; the page binds only to these properties.
 */
Singleton {
    id: root

    readonly property bool available: true
    readonly property string currentVersion: "2026.06.13"
    readonly property string latestVersion: "2026.06.20"
    readonly property string branch: "main"
    readonly property string checkedAgo: "12m ago"
    readonly property int behind: commits.length

    // Newest first. `area` matches the repo's commit-subject area labels
    // (global | installation | system | ryoku | docs | tooling | release).
    readonly property var commits: [
        { hash: "9f3c1ab", area: "global",       subject: "keep the pill open while hovering the open-app tray icons", date: "2h ago" },
        { hash: "1d77e02", area: "ryoku",        subject: "hub: quit on window close so Super+, never sticks", date: "3h ago" },
        { hash: "b42a9c5", area: "system",       subject: "display: prefer the discrete GPU for the compositor", date: "6h ago" },
        { hash: "7c0e8f1", area: "ryoku",        subject: "pill: fold the weather glyph into the hover clock", date: "yesterday" },
        { hash: "3aa5d6e", area: "installation", subject: "tui: validate the disk layout before partitioning", date: "yesterday" },
        { hash: "5e1b240", area: "docs",         subject: "frame: document the blob neck and the reveal curve", date: "2 days ago" }
    ]
}
