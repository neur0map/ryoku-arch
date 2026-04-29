pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// WallpaperService — wallpaper list + apply pipeline
//
// Flow:
//   Component.onCompleted → readConfigProc (sets currentWall etc.)
//                         → refresh() (populates wallpapers list)
//   apply(path)           → ryoku-theme-bg-set
//                         → saveConfig() (writes src/user_data/wallpaper.json)
// ============================================================

QtObject {
    id: root

    // ── Config path — src/user_data/wallpaper.json (relative to this file) ──────
    readonly property string configPath: Qt.resolvedUrl("../user_data/wallpaper.json")
                                            .toString().replace(/^file:\/\//, "")

    // ── State ─────────────────────────────────────────────────────────────────
    property var    wallpapers:   []
    property string currentWall:  ""
    property string previewWall:  ""
    property string scheme:       "content"
    property bool   applying:     false
    property string wallpaperDir: Quickshell.env("HOME") + "/.config/ryoku/current/theme/backgrounds"

    readonly property var schemes: [
        "content", "tonal-spot", "fidelity","fruit-salad", "neutral", "monochrome"
    ]

    // Emitted when the full apply pipeline exits cleanly (exitCode === 0).
    signal wallpaperApplied(string path)

    // ── File listing ──────────────────────────────────────────────────────────
    function refresh() {
        if (listProc.running) return
        root.wallpapers = []
        listProc.running = true
    }

    property var listProc: Process {
        command: [
            "bash", "-lc",
            "theme_name=$(cat \"$HOME/.config/ryoku/current/theme.name\" 2>/dev/null); " +
            "find -L \"$HOME/.config/ryoku/backgrounds/$theme_name\" " +
            "\"$HOME/.config/ryoku/current/theme/backgrounds\" " +
            "-maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' " +
            "-o -iname '*.png' -o -iname '*.gif' -o -iname '*.webp' \\) " +
            "-print 2>/dev/null | sort -u"
        ]
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t !== "") root.wallpapers = root.wallpapers.concat([t])
            }
        }
    }

    // ── Config read — runs on startup, then calls refresh() ──────────────────
    property string _cfgBuf: ""
    property var readConfigProc: Process {
        // Ryoku: drop the shell wrapper; pass path as a Process arg directly.
        // Eliminates single-quote-escape injection in path strings. Note:
        // the write path at lines ~90-91 still shell-interpolates configPath,
        // but configPath is hardcoded internal (Qt.resolvedUrl of a vendored
        // user_data path), so practical risk is bounded. A follow-up spec
        // can patch the write path; out of scope for Spec 1.
        command: ["cat", root.configPath]
        stdout: SplitParser {
            onRead: function(line) { root._cfgBuf += line }
        }
        onExited: function() {
            if (root._cfgBuf !== "") {
                try {
                    var obj = JSON.parse(root._cfgBuf)
                    if (obj.currentWall  && obj.currentWall  !== "") root.currentWall  = obj.currentWall
                    if (obj.wallpaperDir && obj.wallpaperDir !== "") root.wallpaperDir = obj.wallpaperDir
                    if (obj.scheme       && obj.scheme       !== "") root.scheme       = obj.scheme
                } catch(e) {}
            }
            root.refresh()
        }
    }

    // ── Config write — called after a successful apply ────────────────────────
    function saveConfig() {
        var json = JSON.stringify({
            currentWall:  root.currentWall,
            wallpaperDir: root.wallpaperDir,
            scheme:       root.scheme
        })
        // Use printf so the content is never misinterpreted as shell commands.
        // Single-quote the config path (paths rarely contain single quotes).
        saveConfigProc.command = [
            "bash", "-c",
            "mkdir -p \"$(dirname '" + root.configPath + "')\" && " +
            "printf '%s' '" + json.replace(/'/g, "'\\''") + "' > '" + root.configPath + "'"
        ]
        saveConfigProc.running = true
    }

    property var saveConfigProc: Process {}   // silent — no stdout/stderr needed

    // ── Apply pipeline ────────────────────────────────────────────────────────
    function apply(path) {
        if (root.applying || path === "") return
        root.applying    = true
        root.currentWall = path
        applyProc.command = [
            Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-theme-bg-set",
            path
        ]
        applyProc.running = true
    }

    property var applyProc: Process {
        onExited: function(exitCode, exitStatus) {
            root.applying = false
            if (exitCode === 0) {
                root.wallpaperApplied(root.currentWall)
                root.saveConfig()
            }
        }
    }

    // Read config first (sets currentWall/wallpaperDir/scheme), then refresh()
    Component.onCompleted: readConfigProc.running = true
}
