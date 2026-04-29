pragma Singleton
import QtQuick
import Quickshell.Io

// ============================================================
// WallpaperService — wallpaper list + apply pipeline
//
// Flow:
//   Component.onCompleted → readConfigProc (sets currentWall etc.)
//                         → refresh() (populates wallpapers list)
//   apply(path)           → awww img + ln -sf ~/.curr_wall + matugen
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
    property string wallpaperDir: "~/Pictures/Wallpapers"

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
            "bash", "-c",
            "find " + root.wallpaperDir + " -maxdepth 1 -type f " +
            "\\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' " +
            "-o -iname '*.gif' -o -iname '*.webp' \\) | sort"
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
        command: ["bash", "-c", "cat '" + root.configPath + "' 2>/dev/null"]
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
            "bash", "-c",
            "awww img --transition-type grow --transition-step 200 --transition-duration 1.2 --transition-fps 60 --transition-pos bottom \"" + path + "\" " +
            "&& ln -sf \"" + path + "\" ~/.curr_wall " +
            "&& if [[ \"" + path + "\" == *.gif ]]; then " +
            "rm -f ~/.curr_wall_static.jpg && magick \"" + path + "[0]\" ~/.curr_wall_static.jpg; " +
            "else ln -sf \"" + path + "\" ~/.curr_wall_static.jpg; fi " +
            "&& matugen image \"$(readlink -f ~/.curr_wall)\" --source-color-index 0 --type scheme-" + root.scheme
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
