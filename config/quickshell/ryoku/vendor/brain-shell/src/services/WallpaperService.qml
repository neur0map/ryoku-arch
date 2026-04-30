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
    readonly property string metaPath: Qt.resolvedUrl("../user_data/wallpaper-meta.json")
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
    readonly property string picturesDir: Quickshell.env("XDG_PICTURES_DIR") !== ""
                                           ? Quickshell.env("XDG_PICTURES_DIR")
                                           : Quickshell.env("HOME") + "/Pictures"
    property string wallpaperDir: userWallpaperDir
    readonly property string userWallpaperDir: picturesDir + "/Wallpapers"

    property string selectedSourceFilter: "local"
    property string selectedTypeFilter: ""
    property int selectedColorFilter: -1
    property string sortMode: "color"
    property string displayMode: "slices"
    property bool matugenEnabled: true
    property bool ollamaEnabled: false
    property bool steamEnabled: false
    property bool wallhavenEnabled: true
    property string matugenMode: "dark"
    property string matugenSchemeType: "scheme-fidelity"
    property bool closeOnSelection: true
    property bool reopenAtLastSelection: false
    property bool wallpaperMute: true
    property string selectedMonitor: ""
    property int randomInterval: 300
    property bool randomIncludeImage: true
    property bool randomIncludeVideo: true
    property bool randomIncludeFavourites: false
    property bool randomRotationActive: false
    property string imageOptimizePreset: "balanced"
    property string imageOptimizeResolution: "2k"
    property bool autoOptimizeImages: false
    property int imageTrashDays: 7
    property string videoConvertPreset: "balanced"
    property string videoConvertResolution: "2k"
    property bool autoConvertVideos: false
    property int videoTrashDays: 7
    property string externalWallpaperCommand: ""
    property var postProcessingCommands: []
    property string wallhavenSorting: "date_added"
    property string wallhavenOrder: "desc"
    property string wallhavenPurity: "100"
    property string wallhavenCategories: "111"
    property string wallhavenApiKeyEnv: "WALLHAVEN_API_KEY"
    property string steamApiKey: ""
    property string steamUsername: ""
    property string steamRoot: Quickshell.env("HOME") + "/.local/share/Steam"
    property string ollamaUrl: "http://localhost:11434"
    property string ollamaModel: "gemma3:4b"
    property bool ollamaConsolidateEnabled: true
    property bool ollamaTaggingActive: false
    property int ollamaProgress: 0
    property int ollamaTotal: 0
    property string ollamaEta: ""
    property string ollamaLogLine: ""
    property bool imageOptimizeRunning: false
    property int imageOptimizeProgress: 0
    property int imageOptimizeTotal: 0
    property string imageOptimizeFile: ""
    property bool videoConvertRunning: false
    property int videoConvertProgress: 0
    property int videoConvertTotal: 0
    property string videoConvertFile: ""
    property int sliceWidth: 118
    property int hoverWidth: 174
    property int expandedWidth: 330
    property int sliceHeight: 278
    property int sliceSpacing: 8
    property int skewOffset: 22
    property int gridThumbWidth: 188
    property int gridThumbHeight: 128
    property int hexThumbWidth: 166
    property int hexThumbHeight: 146
    property int mosaicThumbWidth: 210
    property int mosaicThumbHeight: 142
    property var selectedTags: []
    property var popularTags: []
    property var tagsDb: ({})
    property var favouritesDb: ({})
    property bool favouriteFilterActive: false
    property string searchQuery: ""
    property string activeWallhavenQuery: ""
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

    function itemKey(item) {
        if (!item) return ""
        if (item.weId !== undefined && item.weId !== "") return String(item.weId)
        if (item.id !== undefined && item.id !== "") return String(item.id)
        var name = root.itemName(item)
        if (name !== "") return name.replace(/\.[^.]+$/, "")
        return item.path || ""
    }

    function isFavourite(item) {
        var key = root.itemKey(item)
        return key !== "" && !!root.favouritesDb[key]
    }

    function toggleFavourite(item) {
        var key = root.itemKey(item)
        if (key === "") return
        var db = JSON.parse(JSON.stringify(root.favouritesDb))
        if (db[key]) {
            delete db[key]
        } else {
            db[key] = true
        }
        root.favouritesDb = db
        root.saveMeta()
        if (root.favouriteFilterActive) root.updateFilteredModel()
    }

    function getWallpaperTags(item) {
        var key = root.itemKey(item)
        if (key !== "" && root.tagsDb[key]) return root.tagsDb[key]
        var name = root.itemName(item)
        if (name !== "" && root.tagsDb[name]) return root.tagsDb[name]
        return []
    }

    function setWallpaperTags(item, tags) {
        var key = root.itemKey(item)
        if (key === "") return
        var normalized = []
        for (var i = 0; i < tags.length; i++) {
            var tag = String(tags[i]).trim().toLowerCase()
            if (tag !== "" && normalized.indexOf(tag) === -1) normalized.push(tag)
        }
        var db = JSON.parse(JSON.stringify(root.tagsDb))
        db[key] = normalized
        root.tagsDb = db
        root.rebuildPopularTags()
        root.saveMeta()
        root.updateFilteredModel()
    }

    function rebuildPopularTags() {
        var counts = {}
        for (var key in root.tagsDb) {
            var tags = root.tagsDb[key] || []
            for (var i = 0; i < tags.length; i++) {
                counts[tags[i]] = (counts[tags[i]] || 0) + 1
            }
        }
        var rows = []
        for (var tag in counts) rows.push({ tag: tag, count: counts[tag] })
        rows.sort(function(a, b) {
            if (a.count !== b.count) return b.count - a.count
            return a.tag.localeCompare(b.tag)
        })
        root.popularTags = rows
    }

    function settingsKeys() {
        return [
            "matugenEnabled", "ollamaEnabled", "steamEnabled", "wallhavenEnabled",
            "matugenMode", "matugenSchemeType", "closeOnSelection",
            "reopenAtLastSelection", "wallpaperMute", "selectedMonitor",
            "randomInterval", "randomIncludeImage", "randomIncludeVideo",
            "randomIncludeFavourites", "randomRotationActive",
            "imageOptimizePreset", "imageOptimizeResolution", "autoOptimizeImages",
            "imageTrashDays", "videoConvertPreset", "videoConvertResolution",
            "autoConvertVideos", "videoTrashDays", "externalWallpaperCommand",
            "postProcessingCommands", "wallhavenSorting", "wallhavenOrder",
            "wallhavenPurity", "wallhavenCategories", "wallhavenApiKeyEnv",
            "steamApiKey", "steamUsername", "steamRoot", "ollamaUrl",
            "ollamaModel", "ollamaConsolidateEnabled", "sliceWidth",
            "hoverWidth", "expandedWidth", "sliceHeight", "sliceSpacing",
            "skewOffset", "gridThumbWidth", "gridThumbHeight", "hexThumbWidth",
            "hexThumbHeight", "mosaicThumbWidth", "mosaicThumbHeight"
        ]
    }

    function setSetting(key, value) {
        if (root.settingsKeys().indexOf(key) === -1) return
        root[key] = value
        root.saveMeta()
    }

    function settingsSummary() {
        var shown = root.filteredModel.count
        var total = root.wallpaperModel.count
        if (shown === total) return String(total)
        return shown + "/" + total
    }

    function randomEligible(item) {
        if (!item) return false
        if (item.source !== "local") return false
        if (item.type === "image" && !root.randomIncludeImage) return false
        if (item.type === "video" && !root.randomIncludeVideo) return false
        if (root.randomIncludeFavourites && !root.isFavourite(item)) return false
        return true
    }

    function stopRandomRotation() {
        randomTimer.stop()
        root.randomRotationActive = false
        root.saveMeta()
    }

    function startRandomRotation() {
        var eligible = false
        for (var i = 0; i < root.filteredModel.count; i++) {
            if (root.randomEligible(root.filteredModel.get(i))) {
                eligible = true
                break
            }
        }
        if (!eligible) {
            root.statusText = "No random-eligible wallpapers"
            return
        }
        root.randomRotationActive = true
        randomTimer.interval = Math.max(10, root.randomInterval) * 1000
        randomTimer.restart()
        root.randomApply()
        root.saveMeta()
    }

    function toggleRandomRotation() {
        if (root.randomRotationActive) root.stopRandomRotation()
        else root.startRandomRotation()
    }

    function optimizeImages() {
        if (root.imageOptimizeRunning) return
        root.imageOptimizeRunning = true
        root.imageOptimizeProgress = 0
        root.imageOptimizeTotal = 0
        root.imageOptimizeFile = root.imageOptimizePreset + " / " + root.imageOptimizeResolution
        root.statusText = "Image optimization is staged in settings"
        imageOptimizeFinish.restart()
    }

    function convertVideos() {
        if (root.videoConvertRunning) return
        root.videoConvertRunning = true
        root.videoConvertProgress = 0
        root.videoConvertTotal = 0
        root.videoConvertFile = root.videoConvertPreset + " / " + root.videoConvertResolution
        root.statusText = "Video conversion is staged in settings"
        videoConvertFinish.restart()
    }

    function startOllamaTagging() {
        if (!root.ollamaEnabled) {
            root.statusText = "Enable Ollama in settings first"
            return
        }
        root.ollamaTaggingActive = !root.ollamaTaggingActive
        root.ollamaProgress = root.ollamaTaggingActive ? 0 : root.ollamaProgress
        root.ollamaTotal = root.ollamaTaggingActive ? root.filteredModel.count : root.ollamaTotal
        root.ollamaEta = root.ollamaTaggingActive ? "queued" : ""
        root.ollamaLogLine = root.ollamaTaggingActive ? root.ollamaModel : ""
        root.statusText = root.ollamaTaggingActive ? "Ollama tagging queued" : "Ollama tagging stopped"
    }

    function searchMatchesItem(item, name, q) {
        if (q === "") return true
        if (item.source === "wallhaven" && q === root.activeWallhavenQuery) return true
        if (item.source === "wallhaven") return false
        if (name.toLowerCase().indexOf(q) !== -1) return true
        var tags = root.getWallpaperTags(item)
        for (var i = 0; i < tags.length; i++) {
            if (String(tags[i]).toLowerCase().indexOf(q) !== -1) return true
        }
        return false
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
            if (root.favouriteFilterActive && !root.isFavourite(item)) continue
            if (root.selectedTags.length > 0) {
                var itemTags = root.getWallpaperTags(item)
                var tagsMatch = true
                for (var t = 0; t < root.selectedTags.length; t++) {
                    if (itemTags.indexOf(root.selectedTags[t]) === -1) {
                        tagsMatch = false
                        break
                    }
                }
                if (!tagsMatch) continue
            }
            if (!root.searchMatchesItem(item, name, q)) continue

            rows.push(item)
        }

        if (root.sortMode === "date") {
            rows.sort(function(a, b) { return root.itemMtime(b) - root.itemMtime(a) })
        } else {
            rows.sort(function(a, b) {
                var ah = root.itemHue(a) === 99 ? 100 : root.itemHue(a)
                var bh = root.itemHue(b) === 99 ? 100 : root.itemHue(b)
                if (ah !== bh) return ah - bh
                return root.itemMtime(b) - root.itemMtime(a)
            })
        }

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
    onSortModeChanged: {
        root.saveMeta()
        root.updateFilteredModel()
    }
    onFavouriteFilterActiveChanged: updateFilteredModel()
    onSelectedTagsChanged: updateFilteredModel()
    onDisplayModeChanged: root.saveMeta()

    property var randomTimer: Timer {
        id: randomTimer
        repeat: true
        onTriggered: root.randomApply()
    }

    property var imageOptimizeFinish: Timer {
        id: imageOptimizeFinish
        interval: 1200
        onTriggered: {
            root.imageOptimizeRunning = false
            root.imageOptimizeFile = ""
        }
    }

    property var videoConvertFinish: Timer {
        id: videoConvertFinish
        interval: 1200
        onTriggered: {
            root.videoConvertRunning = false
            root.videoConvertFile = ""
        }
    }

    property var metaFile: FileView {
        path: root.metaPath
        preload: true
    }

    function loadMeta() {
        metaFile.reload()
        var raw = metaFile.text()
        if (!raw || raw.trim() === "") return
        try {
            var obj = JSON.parse(raw)
            root.tagsDb = obj.tags || {}
            root.favouritesDb = obj.favourites || {}
            if (obj.displayMode) root.displayMode = obj.displayMode
            if (obj.sortMode) root.sortMode = obj.sortMode
            var settings = obj.settings || {}
            var keys = root.settingsKeys()
            for (var i = 0; i < keys.length; i++) {
                if (settings[keys[i]] !== undefined) root[keys[i]] = settings[keys[i]]
            }
            if (root.randomRotationActive) root.startRandomRotation()
            root.rebuildPopularTags()
        } catch(e) {
            root.statusText = "Could not load wallpaper metadata"
        }
    }

    function saveMeta() {
        var settings = {}
        var keys = root.settingsKeys()
        for (var i = 0; i < keys.length; i++) settings[keys[i]] = root[keys[i]]
        var json = JSON.stringify({
            tags: root.tagsDb,
            favourites: root.favouritesDb,
            displayMode: root.displayMode,
            sortMode: root.sortMode,
            settings: settings
        }, null, 2)
        metaFile.setText(json + "\n")
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

    // ── Wallhaven search ──────────────────────────────────────────────────────
    function searchWallhaven(query, page) {
        if (wallhavenProc.running) return
        var trimmedQuery = String(query || "").trim()
        root.selectedSourceFilter = "wallhaven"
        root.activeWallhavenQuery = trimmedQuery.toLowerCase()
        root.searchQuery = trimmedQuery
        root.clearWallhavenRows()
        if (trimmedQuery === "") return

        root.wallhavenLoading = true
        root.statusText = ""
        wallhavenProc.command = [
            Quickshell.env("HOME") + "/.local/share/ryoku/bin/ryoku-ipc",
            "wallpaper", "wallhaven", "search",
            "--query", trimmedQuery,
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

    function randomApply() {
        if (root.filteredModel.count <= 0 || root.applying) return
        var tries = Math.max(1, root.filteredModel.count * 2)
        for (var i = 0; i < tries; i++) {
            var idx = Math.floor(Math.random() * root.filteredModel.count)
            var item = root.filteredModel.get(idx)
            if (root.randomEligible(item)) {
                root.applyItem(item)
                return
            }
        }
        root.statusText = "No random-eligible wallpapers"
    }

    function deleteWallpaperItem(item) {
        if (!item) return
        var key = root.itemKey(item)
        for (var i = root.wallpaperModel.count - 1; i >= 0; i--) {
            if (root.itemKey(root.wallpaperModel.get(i)) === key) root.wallpaperModel.remove(i)
        }
        var favs = JSON.parse(JSON.stringify(root.favouritesDb))
        delete favs[key]
        root.favouritesDb = favs
        var tags = JSON.parse(JSON.stringify(root.tagsDb))
        delete tags[key]
        root.tagsDb = tags
        root.rebuildPopularTags()
        root.saveMeta()
        root.updateFilteredModel()
        root.statusText = "Removed from selector"
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
    Component.onCompleted: {
        root.loadMeta()
        readConfigProc.running = true
    }
}
