pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// ============================================================
// WallpaperService — wallpaper model + apply pipeline
//
// Flow:
//   Component.onCompleted → readConfigProc (sets currentWall etc.)
//                         → refresh() (populates wallpaperModel)
//   applyItem(item)       → ryoku-ipc wallpaper apply --type image|video PATH
//                         → saveConfig() (writes src/user_data/wallpaper.json)
// ============================================================

QtObject {
    id: root

    // ── Config path — src/user_data/wallpaper.json (relative to this file) ──────
    readonly property string configPath: Qt.resolvedUrl("../user_data/wallpaper.json")
                                            .toString().replace(/^file:\/\//, "")

    // ── State ─────────────────────────────────────────────────────────────────
    property var wallpaperModel: ListModel {}
    property var filteredModel: ListModel {}

    // Compatibility view for the pre-SKWD WallpaperPopup until Task 8 lands.
    property var    wallpapers:   []
    property string currentWall:  ""
    property string previewWall:  ""
    property string scheme:       "content"
    property bool   applying:     false
    property string wallpaperDir: Quickshell.env("HOME") + "/.config/ryoku/current/theme/backgrounds"
    readonly property string userWallpaperDir: Quickshell.env("HOME") + "/.config/ryoku/backgrounds/"

    property string selectedSourceFilter: "local"
    property string selectedTypeFilter: ""
    property int selectedColorFilter: -1
    property string searchQuery: ""
    property string statusText: ""
    property bool wallhavenLoading: false
    property string pendingApplyPath: ""
    property string pendingApplyType: ""
    property string pendingDownloadId: ""
    property string pendingDownloadUrl: ""
    property string downloadedWallhavenPath: ""
    property bool listLoading: false
    property bool cacheRebuilding: false
    property bool reloadAfterRebuild: false
    readonly property bool cacheLoading: listLoading || cacheRebuilding

    readonly property var schemes: [
        "content", "tonal-spot", "fidelity","fruit-salad", "neutral", "monochrome"
    ]

    // Emitted when the full apply pipeline exits cleanly (exitCode === 0).
    signal wallpaperApplied(string path)

    // ── Model loading/filtering ───────────────────────────────────────────────
    function refresh() {
        if (listProc.running) return
        root.listLoading = true
        root.statusText = ""
        root.wallpaperModel.clear()
        root.filteredModel.clear()
        root.wallpapers = []
        listProc.command = [
            Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
            "wallpaper", "list", "--jsonl"
        ]
        listProc.running = true
    }

    function rebuildCache() {
        if (cacheRebuildProc.running) return
        root.cacheRebuilding = true
        root.statusText = ""
        cacheRebuildProc.command = [
            Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
            "wallpaper", "cache", "rebuild"
        ]
        cacheRebuildProc.running = true
    }

    property var listProc: Process {
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t === "") return
                try {
                    var obj = JSON.parse(t)
                    root.wallpaperModel.append(obj)
                } catch(e) {
                    root.statusText = "Could not parse wallpaper cache"
                }
            }
        }
        onExited: function(exitCode, exitStatus) {
            root.listLoading = false
            if (exitCode !== 0) root.statusText = "Could not load wallpaper cache"
            root.updateFilteredModel()
            if (root.reloadAfterRebuild) {
                root.reloadAfterRebuild = false
                root.refresh()
            }
        }
    }

    property var cacheRebuildProc: Process {
        onExited: function(exitCode, exitStatus) {
            root.cacheRebuilding = false
            if (exitCode === 0) {
                root.statusText = "Cache rebuilt"
                if (listProc.running) {
                    root.reloadAfterRebuild = true
                } else {
                    root.refresh()
                }
            } else {
                root.statusText = "Could not rebuild cache"
            }
        }
    }

    function itemName(item) {
        if (item.name) return item.name
        if (!item.path) return ""
        var parts = item.path.split("/")
        return parts.length > 0 ? parts[parts.length - 1] : item.path
    }

    function itemHue(item) {
        return item.hue === undefined ? 99 : Number(item.hue)
    }

    function itemMtime(item) {
        return item.mtime === undefined ? 0 : Number(item.mtime)
    }

    function updateFilteredModel() {
        var rows = []
        var paths = []
        var q = root.searchQuery.toLowerCase()

        for (var i = 0; i < root.wallpaperModel.count; i++) {
            var item = root.wallpaperModel.get(i)
            var name = root.itemName(item)

            if (root.selectedSourceFilter !== "" && item.source !== root.selectedSourceFilter) continue
            if (root.selectedTypeFilter !== "" && item.type !== root.selectedTypeFilter) continue
            if (root.selectedColorFilter >= 0 && root.itemHue(item) !== root.selectedColorFilter) continue
            if (q !== "" && name.toLowerCase().indexOf(q) === -1) continue

            rows.push(item)
        }

        rows.sort(function(a, b) {
            var ah = root.itemHue(a) === 99 ? 100 : root.itemHue(a)
            var bh = root.itemHue(b) === 99 ? 100 : root.itemHue(b)
            if (ah !== bh) return ah - bh
            return root.itemMtime(b) - root.itemMtime(a)
        })

        root.filteredModel.clear()
        for (var j = 0; j < rows.length; j++) {
            root.filteredModel.append(rows[j])
            if (rows[j].path) paths.push(rows[j].path)
        }
        root.wallpapers = paths
    }

    function clearWallhavenRows() {
        for (var i = root.wallpaperModel.count - 1; i >= 0; i--) {
            var item = root.wallpaperModel.get(i)
            if (item.source === "wallhaven") root.wallpaperModel.remove(i)
        }
        root.updateFilteredModel()
    }

    onSelectedSourceFilterChanged: updateFilteredModel()
    onSelectedTypeFilterChanged: updateFilteredModel()
    onSelectedColorFilterChanged: updateFilteredModel()
    onSearchQueryChanged: updateFilteredModel()

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

    // ── Wallhaven search ──────────────────────────────────────────────────────
    function searchWallhaven(query, page) {
        if (wallhavenProc.running) return
        root.wallhavenLoading = true
        root.statusText = ""
        root.clearWallhavenRows()
        root.selectedSourceFilter = "wallhaven"
        wallhavenProc.command = [
            Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
            "wallpaper", "wallhaven", "search",
            "--query", query,
            "--page", String(page || 1),
            "--json"
        ]
        wallhavenProc.running = true
    }

    property var wallhavenProc: Process {
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t === "") return
                try {
                    var obj = JSON.parse(t)
                    root.wallpaperModel.append(obj)
                } catch(e) {
                    root.statusText = "Could not parse Wallhaven result"
                }
            }
        }
        onExited: function(exitCode, exitStatus) {
            root.wallhavenLoading = false
            if (exitCode !== 0) root.statusText = "Could not search Wallhaven"
            root.updateFilteredModel()
        }
    }

    // ── Apply pipeline ────────────────────────────────────────────────────────
    // Image apply is routed through ryoku-ipc; its backend owns ryoku-theme-bg-set.
    function isRemotePath(path) {
        return path.indexOf("https://") === 0 || path.indexOf("http://") === 0
    }

    function wallhavenId(item) {
        if (item.id !== undefined && item.id !== "") return String(item.id)
        var name = root.itemName(item)
        if (name.indexOf("wallhaven-") === 0) return name.substring(10)
        return ""
    }

    function applyItem(item) {
        if (root.applying || !item || !item.path || item.path === "") return
        root.applying    = true
        root.statusText  = ""

        if (item.source === "wallhaven" || root.isRemotePath(item.path)) {
            var id = root.wallhavenId(item)
            if (id === "") {
                root.applying = false
                root.statusText = "Could not identify Wallhaven wallpaper"
                return
            }
            root.pendingDownloadId = id
            root.pendingDownloadUrl = item.path
            root.downloadedWallhavenPath = ""
            downloadProc.command = [
                Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
                "wallpaper", "wallhaven", "download",
                root.pendingDownloadId,
                root.pendingDownloadUrl
            ]
            downloadProc.running = true
            return
        }

        root.startApply(item.path, item.type)
    }

    function startApply(path, type) {
        root.pendingApplyPath = path
        root.pendingApplyType = type === "video" ? "video" : "image"
        applyProc.command = [
            Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
            "wallpaper", "apply", "--type", root.pendingApplyType,
            root.pendingApplyPath
        ]
        applyProc.running = true
    }

    function typeForPath(path) {
        var lower = path.toLowerCase()
        if (lower.match(/\.(mp4|mkv|webm|mov|avi)$/)) return "video"
        return "image"
    }

    function apply(path) {
        root.applyItem({
            path: path,
            type: root.typeForPath(path)
        })
    }

    property var downloadProc: Process {
        stdout: SplitParser {
            onRead: function(line) {
                var t = line.trim()
                if (t !== "") root.downloadedWallhavenPath = t
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode === 0 && root.downloadedWallhavenPath !== "") {
                root.startApply(root.downloadedWallhavenPath, "image")
            } else {
                root.applying = false
                root.statusText = "Could not download wallpaper"
            }
            root.pendingDownloadId = ""
            root.pendingDownloadUrl = ""
            root.downloadedWallhavenPath = ""
        }
    }

    property var applyProc: Process {
        onExited: function(exitCode, exitStatus) {
            root.applying = false
            if (exitCode === 0) {
                root.currentWall = root.pendingApplyPath
                root.wallpaperApplied(root.currentWall)
                root.saveConfig()
            } else {
                root.statusText = "Could not apply wallpaper"
            }
            root.pendingApplyPath = ""
            root.pendingApplyType = ""
        }
    }

    // Read config first (sets currentWall/wallpaperDir/scheme), then refresh()
    Component.onCompleted: readConfigProc.running = true
}
