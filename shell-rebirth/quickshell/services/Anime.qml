pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string apiUrl: "http://127.0.0.1:5050"

    property list<var> animeList: []
    property bool isFetchingAnime: false
    property string animeError: ""
    property bool hasMoreAnime: false
    property int popularPage: 1
    property int latestPage: 1
    property string currentSearchText: ""
    property string currentMode: "sub"
    property string currentCountry: "ALL"
    property string currentView: ""

    property var currentAnime: null
    property bool isFetchingDetail: false
    property string detailError: ""

    property list<var> streamLinks: []
    property var selectedLink: null
    property bool isFetchingLinks: false
    property string linksError: ""
    property string currentEpisode: ""

    // ── Library ───────────────────────────────────────────────────────────────
    // Each entry: { id, name, englishName, thumbnail, score,
    //               lastWatchedEpId, lastWatchedEpNum,
    //               bookmarked, addedAt }
    property list<var> libraryList: []
    property bool libraryLoaded: false

    readonly property string _libraryPath:
        Quickshell.env("HOME") + "/.local/share/quickshell/anime_library.json"

    FileView {
        id: libraryFile
        path: root._libraryPath
        onLoaded: {
            try {
                var data = JSON.parse(libraryFile.text())
                root.libraryList = Array.isArray(data) ? data : []
            } catch (e) {
                console.warn("[ServiceAnime] library parse error:", e)
                root.libraryList = []
            }
            root.libraryLoaded = true
            console.log("[ServiceAnime] Library loaded —", root.libraryList.length, "entries")
        }
        onLoadFailed: {
            root.libraryList = []
            root.libraryLoaded = true
            console.log("[ServiceAnime] No library file found, starting fresh")
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

    function addToLibrary(anime) {
        if (isInLibrary(anime.id)) return
        var entry = {
            id:                 anime.id,
            name:               anime.name               || "",
            englishName:        anime.englishName         || anime.name || "",
            thumbnail:          anime.thumbnail           || "",
            score:              anime.score               || null,
            lastWatchedEpId:    "",
            lastWatchedEpNum:   "",
            bookmarked:         true,
            addedAt:            new Date().toISOString()
        }
        root.libraryList = [entry, ...root.libraryList]
        _saveLibrary()
        console.log("[ServiceAnime] Added to library:", entry.name)
    }

    function removeFromLibrary(animeId) {
        root.libraryList = root.libraryList.filter(function(e) { return e.id !== animeId })
        _saveLibrary()
        console.log("[ServiceAnime] Removed from library:", animeId)
    }

    function isInLibrary(animeId) {
        return root.libraryList.some(function(e) { return e.id === animeId })
    }

    function isBookmarked(animeId) {
        var entry = getLibraryEntry(animeId)
        return entry ? entry.bookmarked : false
    }

    function toggleBookmark(anime) {
        if (!isInLibrary(anime.id)) {
            addToLibrary(anime)
            return
        }
        root.libraryList = root.libraryList.map(function(e) {
            if (e.id !== anime.id) return e
            return Object.assign({}, e, { bookmarked: !e.bookmarked })
        })
        _saveLibrary()
    }

    function updateLastWatched(animeId, episodeId, episodeNum) {
        if (!isInLibrary(animeId)) return
        root.libraryList = root.libraryList.map(function(e) {
            if (e.id !== animeId) return e
            return Object.assign({}, e, {
                lastWatchedEpId:  episodeId,
                lastWatchedEpNum: String(episodeNum)
            })
        })
        _saveLibrary()
        console.log("[ServiceAnime] Last watched updated —", animeId, "ep.", episodeNum)
    }

    function getLibraryEntry(animeId) {
        for (var i = 0; i < root.libraryList.length; i++) {
            if (root.libraryList[i].id === animeId) return root.libraryList[i]
        }
        return null
    }

    function bookmarkedList() {
        return root.libraryList.filter(function(e) { return e.bookmarked })
    }

    Component.onCompleted: libraryFile.reload()

    property bool serverReady: false

    Process {
        id: serverProcess
        command: [Quickshell.env("HOME") + "/ani-env/bin/python3",
            Quickshell.env("RYOKU_REBIRTH_SHELL_DIR") + "/scripts/anime_server.py"]
        running: true
        onExited: (code) => {
            console.warn("[ServiceAnime] Server exited with code", code, "— restarting")
            root.serverReady = false
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
                    console.log("[ServiceAnime] Backend ready at", root.apiUrl)
                    fetchPopular()
                }
            }
            xhr.open("GET", root.apiUrl + "/health")
            xhr.send()
        }
    }

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


    function fetchPopular(reset) {
        if (isFetchingAnime) return
        if (reset === undefined || reset) {
            animeList = []
            popularPage = 1
        }
        currentView = "popular"
        currentSearchText = ""
        isFetchingAnime = true
        animeError = ""

        const url = root.apiUrl + "/popular?size=20&page=" + popularPage + "&date_range=1"
        _get(url, function(err, body) {
            if (err) { animeError = "Request failed: " + err; isFetchingAnime = false; return }
            _parsePopularResults(body)
        })
    }

    function _parsePopularResults(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { animeError = data.error; isFetchingAnime = false; return }

            const items = data.shows || []
            animeList = [...animeList, ...items.map(function(s) {
                return _normaliseShow(s)
            })]

            // popular endpoint has a fixed total of 500, paged by `size`
            const fetched = popularPage * 20
            hasMoreAnime = fetched < (data.total || 0)
            animeError = ""
        } catch (e) {
            animeError = "Parse error: " + e
            console.error("[ServiceAnime]", e)
        }
        isFetchingAnime = false
    }

    function fetchLatest(reset) {
        if (isFetchingAnime) return
        if (reset === undefined || reset) {
            animeList = []
            latestPage = 1
        }
        currentView = "latest"
        currentSearchText = ""
        isFetchingAnime = true
        animeError = ""

        const url = root.apiUrl + "/latest?limit=26&page=" + latestPage
            + "&mode=" + currentMode
            + "&country=" + currentCountry
        _get(url, function(err, body) {
            if (err) { animeError = "Request failed: " + err; isFetchingAnime = false; return }
            _parseLatestResults(body)
        })
    }

    function _parseLatestResults(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { animeError = data.error; isFetchingAnime = false; return }

            const items = data.shows || []
            animeList = [...animeList, ...items.map(function(s) {
                return _normaliseShow(s)
            })]

            const fetched = latestPage * 26
            hasMoreAnime = fetched < (data.total || 0)
            animeError = ""
        } catch (e) {
            animeError = "Parse error: " + e
            console.error("[ServiceAnime]", e)
        }
        isFetchingAnime = false
    }

    function searchAnime(query, reset) {
        if (isFetchingAnime) return
        if (reset === undefined || reset) { animeList = [] }
        currentView = "search"
        currentSearchText = query
        isFetchingAnime = true
        animeError = ""

        const url = root.apiUrl + "/search?q=" + encodeURIComponent(query)
            + "&mode=" + currentMode
        _get(url, function(err, body) {
            if (err) { animeError = "Request failed: " + err; isFetchingAnime = false; return }
            _parseSearchResults(body)
        })
    }

    function _parseSearchResults(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { animeError = data.error; isFetchingAnime = false; return }

            const items = data.results || []
            animeList = [...animeList, ...items.map(function(s) {
                return _normaliseShow(s)
            })]

            // search endpoint returns all matches at once
            hasMoreAnime = false
            animeError = ""
        } catch (e) {
            animeError = "Parse error: " + e
            console.error("[ServiceAnime]", e)
        }
        isFetchingAnime = false
    }

    function fetchNextPage() {
        if (!hasMoreAnime || isFetchingAnime) return
        if (currentView === "popular") {
            popularPage++
            fetchPopular(false)
        } else if (currentView === "latest") {
            latestPage++
            fetchLatest(false)
        }
    }

    function _normaliseShow(s) {
        var avail = s.available_episodes || {}
        return {
            id:          s.id          || "",
            name:        s.name        || "",
            englishName: s.english_name || s.englishName || s.name || "",
            nativeName:  s.native_name  || s.nativeName  || "",
            thumbnail:   s.thumbnail   || "",
            score:       s.score       !== undefined ? s.score : null,
            type:        s.type        || "",
            episodeCount: s.episode_count || "",
            availableEpisodes: {
                sub: avail.sub || 0,
                dub: avail.dub || 0,
                raw: avail.raw || 0
            },
            // /popular extras
            views:       s.views       || null,
            // /latest extras
            season:      s.season      || null,
            lastEpisode: s.last_episode || null
        }
    }

    function fetchAnimeDetail(show) {
        if (isFetchingDetail) return
        isFetchingDetail = true
        currentAnime = null
        detailError = ""

        // Seed what we already know from the list card immediately
        currentAnime = Object.assign({}, show, { episodes: [] })

        const url = root.apiUrl + "/episodes?id=" + encodeURIComponent(show.id)
            + "&mode=" + currentMode
        _get(url, function(err, body) {
            if (err) { detailError = "Request failed: " + err; isFetchingDetail = false; return }
            _parseAnimeDetail(show, body)
        })
    }

    function _parseAnimeDetail(show, json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { detailError = data.error; isFetchingDetail = false; return }

            const eps = (data.episodes || []).map(function(epNum, idx) {
                return {
                    id:     show.id + "-" + epNum,   // synthetic id: showId-epNumber
                    number: epNum,
                    index:  idx
                }
            })

            currentAnime = Object.assign({}, show, {
                episodes: eps,
                episodeCount: data.count || eps.length
            })
            detailError = ""
        } catch (e) {
            detailError = "Parse error: " + e
            console.error("[ServiceAnime]", e)
        }
        isFetchingDetail = false
    }

    function clearDetail() {
        currentAnime = null
        detailError = ""
        clearStreamLinks()
    }

    function fetchStreamLinks(showId, episodeNum, quality) {
        if (isFetchingLinks) return
        isFetchingLinks = true
        streamLinks = []
        selectedLink = null
        linksError = ""
        currentEpisode = String(episodeNum)

        const q = quality || "best"
        const url = root.apiUrl + "/links?id=" + encodeURIComponent(showId)
            + "&ep=" + encodeURIComponent(episodeNum)
            + "&mode=" + currentMode
            + "&quality=" + encodeURIComponent(q)
        _get(url, function(err, body) {
            if (err) { linksError = "Request failed: " + err; isFetchingLinks = false; return }
            _parseStreamLinks(body)
        })
    }

    function _parseStreamLinks(json) {
        try {
            const data = JSON.parse(json)
            if (data.error) { linksError = data.error; isFetchingLinks = false; return }

            const validLinks = (data.all_links || []).filter(function(l) {
                return !l.error && l.url && l.url.length > 0
            })

            streamLinks = validLinks.map(function(l) {
                return {
                    url:      l.url      || "",
                    quality:  l.quality  || "?",
                    type:     l.type     || "mp4",
                    provider: l.provider || "",
                    referer:  l.referer  || "",
                    subtitle: l.subtitle || ""
                }
            })

            if (streamLinks.length === 0) {
                // All providers failed — surface a meaningful error instead of
                // silently doing nothing.
                linksError = "No working stream found for this episode"
                isFetchingLinks = false
                return
            }

            var sel = data.selected
            if (sel && sel.error) sel = null
            if (sel && (!sel.url || sel.url.length === 0)) sel = null

            selectedLink = sel ? {
                url:      sel.url      || "",
                quality:  sel.quality  || "?",
                type:     sel.type     || "mp4",
                provider: sel.provider || "",
                referer:  sel.referer  || "",
                subtitle: sel.subtitle || ""
            } : streamLinks[0]

            linksError = ""
        } catch (e) {
            linksError = "Parse error: " + e
            console.error("[ServiceAnime]", e)
        }
        isFetchingLinks = false
    }

    function selectLink(link) {
        selectedLink = link
    }

    function clearStreamLinks() {
        streamLinks = []
        selectedLink = null
        linksError = ""
        currentEpisode = ""
    }

    function clearAnimeList() {
        animeList = []
        hasMoreAnime = false
        popularPage = 1
        latestPage = 1
        animeError = ""
    }

    function setMode(mode) {
        if (mode === currentMode) return
        currentMode = mode
        if (currentView === "popular")      fetchPopular(true)
        else if (currentView === "latest")  fetchLatest(true)
        else if (currentView === "search" && currentSearchText.length > 0)
            searchAnime(currentSearchText, true)
    }

    function setCountry(country) {
        if (country === currentCountry) return
        currentCountry = country
        if (currentView === "latest") fetchLatest(true)
    }
}
