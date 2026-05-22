import Quickshell
import Quickshell.Io
import QtCore
import QtQml
import qs.settings

pragma Singleton
pragma ComponentBehavior: Bound

Singleton {
    id: root

    property string wallpaperDir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property string wallpaperScript: Quickshell.env("HOME") + "/.local/bin/setwall"
    property string scheme: "material"
    property string theme: "dark"

    property string currentSearchText: ""
    property string _pendingDownloadPath: ""
    property string downloadingWallpaperId: ""

    // ── Online / Wallhaven ──────────────────────────────────────────────────
    property list<var> onlineWallpapers: []
    property bool isFetchingOnline: false
    property int  onlinePage: 1
    property bool hasMorePages: false
    property string _fetchBuffer: ""
    property string onlineError: ""

    // ── React to SettingsConfig changes and re-fetch ────────────────────────
    Connections {
        target: SettingsConfig
        function onWallhavenCategoriesChanged() { root.fetchWallhaven(true) }
        function onWallhavenPurityChanged()      { root.fetchWallhaven(true) }
        function onWallhavenSortingChanged()     { root.fetchWallhaven(true) }
        function onWallhavenOrderChanged()       { root.fetchWallhaven(true) }
        function onWallhavenTopRangeChanged()    { root.fetchWallhaven(true) }
        function onWallhavenAtleastChanged()     { root.fetchWallhaven(true) }
        function onWallhavenRatiosChanged()      { root.fetchWallhaven(true) }
        function onWallhavenApiKeyChanged()      { root.fetchWallhaven(true) }
    }

    Timer {
        interval: 0
        running: true
        repeat: false
        onTriggered: root.fetchWallhaven(true)
    }

    function buildWallhavenUrl(page) {
        const p = []
        p.push("categories=" + SettingsConfig.wallhavenCategories)
        p.push("purity="     + SettingsConfig.wallhavenPurity)
        p.push("sorting="    + SettingsConfig.wallhavenSorting)
        p.push("order="      + SettingsConfig.wallhavenOrder)
        if (SettingsConfig.wallhavenSorting === "toplist")
            p.push("topRange=" + SettingsConfig.wallhavenTopRange)
        if (SettingsConfig.wallhavenAtleast.length > 0)
            p.push("atleast=" + SettingsConfig.wallhavenAtleast)
        if (SettingsConfig.wallhavenRatios.length > 0)
            p.push("ratios=" + SettingsConfig.wallhavenRatios)
        if (currentSearchText.length > 0)
            p.push("q=" + encodeURIComponent(currentSearchText))
        if (SettingsConfig.wallhavenApiKey.length > 0)
            p.push("apikey=" + SettingsConfig.wallhavenApiKey)
        p.push("page=" + page)
        return "https://wallhaven.cc/api/v1/search?" + p.join("&")
    }

    function fetchWallhaven(resetPage) {
        if (isFetchingOnline) return
        if (resetPage) {
            onlinePage = 1
            onlineWallpapers = []
        }
        isFetchingOnline = true
        onlineError = ""
        _fetchBuffer = ""
        const url = buildWallhavenUrl(onlinePage)
        console.log("[ServiceWallpaper] Fetching Wallhaven page", onlinePage, "–", url)
        wallhavenFetcher.command = ["bash", "-c", "curl -s '" + url + "'"]
        wallhavenFetcher.running = true
    }

    function _parseWallhavenResults(json) {
        try {
            const data = JSON.parse(json)

            if (data.error) {
                onlineError = data.error
                console.error("[ServiceWallpaper] Wallhaven API error:", data.error)
                isFetchingOnline = false
                return
            }

            const items = data.data || []
            const meta  = data.meta || {}

            const parsed = items.map(item => ({
                id:         item.id,
                thumbUrl:   item.thumbs.large,
                fullUrl:    item.path,
                resolution: item.resolution,
                fileType:   item.file_type
            }))

            onlineWallpapers = (onlinePage === 1)
                ? parsed
                : [...onlineWallpapers, ...parsed]

            hasMorePages = (meta.current_page || 1) < (meta.last_page || 1)
            onlineError = ""
            console.log("[ServiceWallpaper] Wallhaven: got", parsed.length,
                "wallpapers, page", meta.current_page, "/", meta.last_page)
        } catch (e) {
            const msg = json.trim()
            onlineError = msg.length > 0 ? msg : "Failed to parse response"
            console.error("[ServiceWallpaper] Wallhaven parse error:", e, "| body:", msg)
        }
        isFetchingOnline = false
    }

    function fetchNextPage() {
        if (!hasMorePages || isFetchingOnline) return
        onlinePage++
        fetchWallhaven(false)
    }

    function updateSearch(searchText) {
        currentSearchText = searchText
        fetchWallhaven(true)
    }

    function downloadAndSetWallpaper(wallpaper) {
        if (_pendingDownloadPath.length > 0) {
            console.warn("[ServiceWallpaper] Download already in progress")
            return
        }
        const ext = wallpaper.fullUrl.split('.').pop().split('?')[0] || "jpg"
        const savePath = root.wallpaperDir + "/" + wallpaper.id + "." + ext
        _pendingDownloadPath = savePath
        downloadingWallpaperId = wallpaper.id
        console.log("[ServiceWallpaper] Downloading wallpaper", wallpaper.id, "->", savePath)
        wallhavenDownloader.command = [
            "bash", "-c",
            "mkdir -p '" + root.wallpaperDir + "' && curl -sL '" + wallpaper.fullUrl + "' -o '" + savePath + "'"
        ]
        wallhavenDownloader.running = true
    }
    // ── End Online ──────────────────────────────────────────────────────────

    Process {
        id: wallpaperSetter

        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("[ServiceWallpaper] Wallpaper set successfully")
            } else {
                console.error("[ServiceWallpaper] Failed to set wallpaper. Exit code:", exitCode)
            }
        }
    }

    // ── Wallhaven processes ─────────────────────────────────────────────────
    Process {
        id: wallhavenFetcher
        stdout: SplitParser {
            onRead: line => { root._fetchBuffer += line }
        }
        onExited: (exitCode) => {
            if (exitCode === 0) {
                root._parseWallhavenResults(root._fetchBuffer)
            } else {
                root.onlineError = "Network error — check your connection (curl exit " + exitCode + ")"
                console.error("[ServiceWallpaper] Wallhaven curl failed, exit:", exitCode)
                root.isFetchingOnline = false
            }
            root._fetchBuffer = ""
        }
    }

    Process {
        id: wallhavenDownloader
        onExited: (exitCode) => {
            if (exitCode === 0) {
                console.log("[ServiceWallpaper] Download complete:", root._pendingDownloadPath)
                wallpaperSetter.exec([wallpaperScript, root._pendingDownloadPath, root.scheme, root.theme])
            } else {
                console.error("[ServiceWallpaper] Download failed for:", root._pendingDownloadPath)
            }
            root._pendingDownloadPath = ""
            root.downloadingWallpaperId = ""
        }
    }
    // ── End Wallhaven processes ─────────────────────────────────────────────
}
