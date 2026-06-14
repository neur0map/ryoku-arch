pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Config
import qs.dashboard.modules.services

// Ryoku: (1) eagerly starts the image-capable ClipboardService so its wl-paste
// watcher captures text + images into clipboard.db from shell startup — it's
// otherwise a lazy, dashboard-only singleton that never ran. (2) enforces the
// history settings (GlobalConfig.clipboard) on that SQLite store: trim-to-limit +
// scheduled age cleanup. Always loaded from shell.qml.
Item {
    id: root

    readonly property var cfg: GlobalConfig.clipboard
    readonly property string dbPath: ClipboardService.dbPath

    Component.onCompleted: {
        // Touch the singleton so it instantiates → Component.onCompleted → initialize()
        // → DB schema + watcher start.
        const _ = ClipboardService.active;
    }

    // Trim history to maxEntries (keep newest non-pinned).
    Timer {
        interval: 120000
        running: root.cfg.enabled && root.cfg.maxEntries > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (trimProc.running)
                return;
            const n = Math.max(1, root.cfg.maxEntries);
            trimProc.command = ["sh", "-lc", 'sqlite3 "' + root.dbPath + '" "DELETE FROM clipboard_items WHERE pinned=0 AND id NOT IN (SELECT id FROM clipboard_items WHERE pinned=0 ORDER BY id DESC LIMIT ' + n + ');" 2>/dev/null || true'];
            trimProc.running = true;
        }
    }
    Process {
        id: trimProc
        onExited: ClipboardService.list()
    }

    // Scheduled cleanup: drop items older than the period (daily = 1 day, weekly = 7).
    Timer {
        interval: 3600000
        running: root.cfg.enabled && root.cfg.autoCleanup !== "off"
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (ageProc.running)
                return;
            const days = root.cfg.autoCleanup === "weekly" ? 7 : 1;
            const cutoff = Math.floor(Date.now() / 1000) - days * 86400;
            ageProc.command = ["sh", "-lc", 'sqlite3 "' + root.dbPath + '" "DELETE FROM clipboard_items WHERE pinned=0 AND created_at < ' + cutoff + ';" 2>/dev/null || true'];
            ageProc.running = true;
        }
    }
    Process {
        id: ageProc
        onExited: ClipboardService.list()
    }
}
