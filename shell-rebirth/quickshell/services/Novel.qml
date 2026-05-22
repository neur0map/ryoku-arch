pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apiUrl: "http://127.0.0.1:5151"

    // ── Novel list ───────────────────────────────────────────────────────────
    property list<var> novelList: []
    property bool isFetchingNovel: false
    property string novelError: ""
    property bool hasMoreNovels: false
    property int currentOffset: 0
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentGenre: ""
    property string currentStatus: "All"

    // ── Novel detail ─────────────────────────────────────────────────────────
    property var currentNovel: null
    property bool isFetchingDetail: false
    property string detailError: ""

    // ── Chapter text ─────────────────────────────────────────────────────────
    property var currentChapter: null
    property bool isFetchingChapter: false
    property string chapterError: ""
    property string currentChapterId: ""

    // ── Provider ─────────────────────────────────────────────────────────────
    property string activeProvider: "novelbin"
    property bool isSwitchingProvider: false
    readonly property var availableProviders: [
        { name: "novelbin",     label: "NovelBin"     },
        { name: "freewebnovel", label: "FreeWebNovel" }
    ]

    function switchProvider(name) {
        if (name === activeProvider || isSwitchingProvider) return
        isSwitchingProvider = true
        _post(root.apiUrl + "/provider/switch", { provider: name }, function(err, body) {
            isSwitchingProvider = false
            if (err) { console.warn("[ServiceNovel] Provider switch failed:", err); return }
            activeProvider = name
            clearNovelList()
            clearDetail()
            clearChapter()
            fetchHot()
        })
    }

    // ── Library ──────────────────────────────────────────────────────────────
    property list<var> libraryList: []
    property bool libraryLoaded: false

    readonly property string _libraryPath:
        Quickshell.env("HOME") + "/.local/share/quickshell/new_novel_library.json"

    FileView {
        id: libraryFile
        path: root._libraryPath
        onLoaded: {
            try {
                var data = JSON.parse(libraryFile.text())
                root.libraryList = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("[ServiceNovel] library parse error:", e)
                root.libraryList = []
            }
            root.libraryLoaded = true
            console.log("[ServiceNovel] Library loaded —", root.libraryList.length, "entries")
        }
        onLoadFailed: {
            root.libraryList = []
            root.libraryLoaded = true
            console.log("[ServiceNovel] No library file found, starting fresh")
        }
    }

    FileView {
        id: libraryWriter
        path: root._libraryPath
    }

    function _saveLibrary() {
        libraryWriter.setText(JSON.stringify(root.libraryList, null, 2))
        libraryWriter.save()
    }

    function addToLibrary(novel) {
        if (isInLibrary(novel.id)) return
        var entry = {
            id:                 novel.id,
            title:              novel.title,
            coverUrl:           novel.coverUrl,
            lastReadChapterId:  "",
            lastReadChapterNum: "",
            addedAt:            new Date().toISOString()
        }
        root.libraryList = [entry, ...root.libraryList]
        _saveLibrary()
        console.log("[ServiceNovel] Added to library:", novel.title)
    }

    function removeFromLibrary(novelId) {
        root.libraryList = root.libraryList.filter(function(e) { return e.id !== novelId })
        _saveLibrary()
        console.log("[ServiceNovel] Removed from library:", novelId)
    }

    function isInLibrary(novelId) {
        return root.libraryList.some(function(e) { return e.id === novelId })
    }

    function updateLastRead(novelId, chapterId, chapterNum) {
        root.libraryList = root.libraryList.map(function(e) {
            if (e.id !== novelId) return e
            return Object.assign({}, e, {
                lastReadChapterId:  chapterId,
                lastReadChapterNum: chapterNum
            })
        })
        _saveLibrary()
        console.log("[ServiceNovel] Last read updated —", novelId, "ch.", chapterNum)
    }

    function getLibraryEntry(novelId) {
        for (var i = 0; i < root.libraryList.length; i++) {
            if (root.libraryList[i].id === novelId) return root.libraryList[i]
        }
        return null
    }

    Component.onCompleted: libraryFile.reload()

    // ── Backend server ───────────────────────────────────────────────────────
    property bool serverReady: false

    Process {
        id: serverProcess
        command: [
            Quickshell.env("HOME") + "/novel-env/bin/python3",
            Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/scripts/novel_server/main.py"
        ]
        running: true
        onExited: (code) => {
            console.warn("[ServiceNovel] Server exited with code", code, "— restarting")
            serverReady = false
            serverProcess.running = true
        }
    }

    Timer {
        id: healthPoller
        interval: 150
        repeat: true
        running: true
        onTriggered: {
            var xhr = new XMLHttpRequest()
            xhr.onreadystatechange = function() {
                if (xhr.readyState === XMLHttpRequest.DONE && xhr.status === 200) {
                    healthPoller.stop()
                    root.serverReady = true
                    console.log("[ServiceNovel] Backend ready at", root.apiUrl)
                    fetchHot()
                }
            }
            xhr.open("GET", root.apiUrl + "/health")
            xhr.send()
        }
    }

    // ── HTTP helpers ──────────────────────────────────────────────────────────
    function _get(url, onDone) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) onDone(null, xhr.responseText)
            else onDone("HTTP " + xhr.status, null)
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function _post(url, data, onDone) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return
            if (xhr.status === 200) onDone(null, xhr.responseText)
            else onDone("HTTP " + xhr.status, null)
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(data))
    }

    // ── Browse / Search ───────────────────────────────────────────────────────
    function fetchHot() {
        if (isFetchingNovel) return
        isFetchingNovel = true
        novelError = ""
        novelList = []
        currentSearchText = ""
        currentGenre = ""
        _get(root.apiUrl + "/hot", function(err, body) {
            if (err) { novelError = "Request failed: " + err; isFetchingNovel = false; return }
            _parseNovelResults(body, true)
        })
    }

    function fetchLatest(reset) {
        if (isFetchingNovel) return
        if (reset) { novelList = []; latestPage = 1 }
        currentSearchText = ""
        isFetchingNovel = true
        novelError = ""
        _get(root.apiUrl + "/latest?page=" + latestPage, function(err, body) {
            if (err) { novelError = "Request failed: " + err; isFetchingNovel = false; return }
            _parseNovelResults(body, false)
        })
    }

    function searchNovels(query, genre, status, reset) {
        if (isFetchingNovel) return
        if (reset) { novelList = []; currentOffset = 0 }
        currentSearchText = query
        currentGenre = genre || ""
        currentStatus = status || "All"
        isFetchingNovel = true
        novelError = ""
        var url = root.apiUrl + "/search?q=" + encodeURIComponent(query) + "&page=1"
        if (genre)  url += "&genre="  + encodeURIComponent(genre)
        if (status && status !== "All") url += "&status=" + encodeURIComponent(status)
        _get(url, function(err, body) {
            if (err) { novelError = "Request failed: " + err; isFetchingNovel = false; return }
            _parseNovelResults(body, false)
        })
    }

    function fetchNextPage() {
        if (!hasMoreNovels || isFetchingNovel) return
        if (currentSearchText.length > 0) {
            currentOffset++
            isFetchingNovel = true
            novelError = ""
            var url = root.apiUrl + "/search?q=" + encodeURIComponent(currentSearchText)
                + "&page=" + (currentOffset + 1)
            if (currentGenre)  url += "&genre="  + encodeURIComponent(currentGenre)
            if (currentStatus && currentStatus !== "All")
                url += "&status=" + encodeURIComponent(currentStatus)
            _get(url, function(err, body) {
                if (err) { novelError = "Request failed: " + err; isFetchingNovel = false; return }
                _parseNovelResults(body, false)
            })
        } else {
            latestPage++
            fetchLatest(false)
        }
    }

    function _parseNovelResults(json, isHot) {
        try {
            const data = JSON.parse(json)
            if (data.error) { novelError = data.error; isFetchingNovel = false; return }

            const items = isHot ? data : (data.results || [])

            novelList = [...novelList, ...items.map(function(item) {
                return {
                    id:            item.id            || "",
                    title:         item.title         || "",
                    coverUrl:      item.image         || "",
                    author:        item.author        || "",
                    latestChapter: item.latestChapter || "",
                    status:        item.status        || ""
                }
            })]

            hasMoreNovels = isHot ? false : (data.hasMore || false)
            novelError = ""
        } catch (e) {
            novelError = "Parse error: " + e
            console.error("[ServiceNovel]", e)
        }
        isFetchingNovel = false
    }

    // ── Novel detail ──────────────────────────────────────────────────────────
    function fetchNovelDetail(novelId) {
        if (isFetchingDetail) return
        isFetchingDetail = true
        currentNovel = null
        detailError = ""
        const url = root.apiUrl + "/info?id=" + encodeURIComponent(novelId)
        _get(url, function(err, body) {
            if (err) { detailError = "Request failed: " + err; isFetchingDetail = false; return }
            _parseNovelDetail(body)
        })
    }

    function _parseNovelDetail(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { detailError = data.error; isFetchingDetail = false; return }
            currentNovel = {
                id:          data.id          || "",
                title:       data.title       || "",
                description: data.description || "",
                status:      data.status      || "",
                author:      data.author      || "",
                coverUrl:    data.image       || "",
                genres:      data.genres      || [],
                chapters:    (data.chapters || []).map(function(ch) {
                    return {
                        id:      ch.id      || "",
                        chapter: ch.chapter || "",
                        title:   ch.title   || ""
                    }
                })
            }
            detailError = ""
        } catch (e) {
            detailError = "Parse error: " + e
            console.error("[ServiceNovel]", e)
        }
        isFetchingDetail = false
    }

    // ── Chapter reading ───────────────────────────────────────────────────────
    function fetchChapter(chapterId) {
        if (isFetchingChapter) return
        isFetchingChapter = true
        currentChapterId = chapterId
        currentChapter = null
        chapterError = ""
        const url = root.apiUrl + "/chapter?id=" + encodeURIComponent(chapterId)
        _get(url, function(err, body) {
            if (err) { chapterError = "Request failed: " + err; isFetchingChapter = false; return }
            _parseChapter(body)
        })
    }

    function _parseChapter(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { chapterError = data.error; isFetchingChapter = false; return }
            currentChapter = {
                id:         data.id         || "",
                title:      data.title      || "",
                paragraphs: data.paragraphs || [],
                wordCount:  data.wordCount  || 0,
                prevId:     data.prevId     || "",
                nextId:     data.nextId     || ""
            }
            chapterError = ""
        } catch (e) {
            chapterError = "Parse error: " + e
            console.error("[ServiceNovel]", e)
        }
        isFetchingChapter = false
    }

    function fetchPrevChapter() {
        if (!currentChapter || currentChapter.prevId === "") return
        fetchChapter(currentChapter.prevId)
    }

    function fetchNextChapter() {
        if (!currentChapter || currentChapter.nextId === "") return
        fetchChapter(currentChapter.nextId)
    }

    // ── Utility ───────────────────────────────────────────────────────────────
    function clearNovelList() {
        novelList = []
        hasMoreNovels = false
        currentOffset = 0
        latestPage = 1
        novelError = ""
    }

    function clearChapter() {
        currentChapter = null
        currentChapterId = ""
        chapterError = ""
    }

    function clearDetail() {
        currentNovel = null
        detailError = ""
    }
}
