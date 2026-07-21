pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The power popup's data plane: who is logged in, how long the box has been up,
// and which wallpaper the desktop is wearing right now. All read-only probes of
// files the shell daemon already maintains, so the popup needs no backend of its
// own. A popup is transient, but a 30s uptime tick keeps "UP 14h 22m" honest if
// it is left open.
Singleton {
    id: s

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (s.home + "/.local/state"))

    // ── who ──────────────────────────────────────────────────────────────
    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "user"
    property string host: "ryoku"

    // ── uptime ───────────────────────────────────────────────────────────
    property real uptimeSecs: 0
    // "14h 22m", "3d 1h", "8m": the two coarsest non-zero units, never seconds.
    readonly property string uptimeText: {
        var t = Math.max(0, Math.floor(s.uptimeSecs));
        var d = Math.floor(t / 86400);
        var h = Math.floor((t % 86400) / 3600);
        var m = Math.floor((t % 3600) / 60);
        if (d > 0)
            return d + "d " + h + "h";
        if (h > 0)
            return h + "h " + m + "m";
        return m + "m";
    }

    // ── wallpaper ──────────────────────────────────────────────────────────
    // The daemon writes the active wallpaper path here on every set; the live
    // still it extracts for wallust sits beside it, and is our instant poster
    // while a clip's video decoder spins up.
    property string wallpaper: ""
    readonly property string livePoster: s.stateDir + "/ryoku-live-frame.png"
    readonly property bool wallIsVideo: {
        var p = s.wallpaper.toLowerCase();
        return p.endsWith(".mp4") || p.endsWith(".webm") || p.endsWith(".mkv") || p.endsWith(".mov");
    }

    FileView {
        id: upFile
        path: "/proc/uptime"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var f = parseFloat((upFile.text() || "0").trim().split(/\s+/)[0]);
            if (!isNaN(f))
                s.uptimeSecs = f;
        }
    }
    FileView {
        id: hostFile
        path: "/etc/hostname"
        blockLoading: true
        printErrors: false
        onLoaded: {
            var h = (hostFile.text() || "").trim();
            if (h.length)
                s.host = h;
        }
    }
    FileView {
        id: wallFile
        path: s.stateDir + "/ryoku-wallpaper"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: s.wallpaper = (wallFile.text() || "").trim()
    }

    // keep uptime fresh while the popup lingers; cheap, one file read.
    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: upFile.reload()
    }
}
