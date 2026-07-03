import QtQuick
import Quickshell.Io
import "../../../Singletons"
import "ytmusic.js" as YtMusic
import "../.."

// YouTube Music search provider (`@` prefix): searches YouTube Music's keyless
// InnerTube API with curl and parses proper songs (clean title/artist/album +
// square album art inline), so results are song-grade and covers are free. A
// prefix cache makes refining a query feel instant; when InnerTube is
// unreachable it falls back to yt-dlp flat search so results never disappear.
// Playing a track hands off to the Radio engine (Singletons/Radio.qml), which
// streams it with mpv and auto-extends an endless YouTube Music radio; this
// provider owns no player. Routed by a dedicated prefix so a plain query never
// forks a search. Availability-gated on yt-dlp + mpv (needed for playback).
Provider {
    id: ytmusic

    providerId: "ytmusic"
    prefix: "@"
    defaultProvider: false
    // Surface unprefixed too, but only for a pasted YouTube link (Dispatcher gates
    // this on Dispatch.looksYtUrl), so `@` still owns text search while a link you
    // paste anywhere becomes a one-tap "Play" without needing the prefix.
    urlFallback: true

    property bool available: false
    property string pendingQuery: ""

    // Prefix-LRU cache: query -> rows. Keeps the last few resolved searches so
    // that refining ("daft" -> "daft punk") shows the widest cached prefix's rows
    // immediately while the network refine runs. Bounded so memory stays flat.
    property var cache: ({})
    property var cacheOrder: []
    readonly property int cacheMax: 16

    function cachePut(q, rows) {
        var c = ytmusic.cache;
        if (!c[q])
            ytmusic.cacheOrder.push(q);
        c[q] = rows;
        while (ytmusic.cacheOrder.length > ytmusic.cacheMax) {
            var evict = ytmusic.cacheOrder.shift();
            delete c[evict];
        }
        ytmusic.cache = c;
    }

    // Exact hit, else the longest cached query that is a prefix of `q` (its rows
    // are a good instant stand-in while the exact search resolves).
    function cacheLookup(q) {
        if (ytmusic.cache[q])
            return ytmusic.cache[q];
        var best = null, bestLen = -1;
        for (var i = 0; i < ytmusic.cacheOrder.length; i++) {
            var k = ytmusic.cacheOrder[i];
            if (q.indexOf(k) === 0 && k.length > bestLen) {
                best = ytmusic.cache[k];
                bestLen = k.length;
            }
        }
        return best;
    }

    function rowFor(track) {
        return {
            id: "ytm:" + track.id,
            title: track.title,
            subtitle: (track.artist ? track.artist : "YouTube Music")
                + (track.album ? "  \u00b7  " + track.album : "")
                + (track.durationLabel ? "  \u00b7  " + track.durationLabel : ""),
            icon: track.cover || "",
            type: "YT Music",
            score: 0,
            actions: [
                { name: "Play", icon: "", execute: function () { Radio.play(track); } },
                { name: "Open", icon: "", execute: function () { Qt.openUrlExternally("https://music.youtube.com/watch?v=" + track.id); } }
            ]
        };
    }

    // A pasted YouTube / YT Music link becomes one "Play" row: a playlist/mix link
    // queues the whole playlist, a bare track link seeds its radio. No network at
    // list time; Radio.playUrl resolves it on play.
    function linkRow(url, parsed) {
        var isList = parsed.playlistId.length > 0;
        return {
            id: "ytm:link:" + url,
            title: isList ? "Play this playlist" : "Play this track",
            subtitle: "YouTube link  \u00b7  " + (isList ? "queues the full playlist" : "starts a radio"),
            icon: "",
            type: "YT Music",
            score: -1,
            actions: [
                { name: "Play", icon: "", execute: function () { Radio.playUrl(url); } },
                { name: "Open", icon: "", execute: function () { Qt.openUrlExternally(url); } }
            ]
        };
    }

    function query(text) {
        if (!ytmusic.available)
            return [];
        var t = (text || "").trim();
        // A pasted link short-circuits search: offer to play it directly.
        var parsed = YtMusic.parseYtUrl(t);
        if (parsed) {
            debounce.stop();
            return [ytmusic.linkRow(t, parsed)];
        }
        if (t.length < 2) {
            debounce.stop();
            return [];
        }
        var cached = ytmusic.cacheLookup(t);
        if (ytmusic.cache[t]) {
            debounce.stop();
            return cached.map(ytmusic.rowFor);   // exact hit: no refetch
        }
        ytmusic.pendingQuery = t;
        // Mark busy on the next tick (not during this binding eval) so the
        // launcher shows its spinner the instant a cold search starts, instead of
        // flashing "No matches" for the debounce window. Deferred to avoid
        // mutating dispatcher state mid-results-eval.
        Qt.callLater(ytmusic.markBusy);
        debounce.restart();
        // prefix hit: show the widest cached prefix's rows while we refine.
        return cached ? cached.map(ytmusic.rowFor) : [];
    }

    function markBusy() {
        // only if a search is still pending or in flight; the query may have
        // been abandoned (cleared, link-pasted, cache-hit) since the callLater.
        if (debounce.running || searchProc.running || fallbackProc.running)
            Dispatcher.setBusy("ytmusic", true);
    }

    Timer {
        id: debounce
        interval: 200
        repeat: false
        onTriggered: {
            searchProc.term = ytmusic.pendingQuery;
            Dispatcher.setBusy("ytmusic", true);
            searchProc.running = false;
            searchProc.running = true;
        }
    }

    Process {
        id: availProc
        command: ["sh", "-c", "command -v yt-dlp >/dev/null 2>&1 && command -v mpv >/dev/null 2>&1"]
        onExited: (code) => { ytmusic.available = (code === 0); }
    }

    // Primary search: InnerTube WEB_REMIX /search. One big JSON object, so it is
    // collected whole and parsed once. Empty results fall through to yt-dlp.
    Process {
        id: searchProc
        property string term: ""
        command: ["curl", "-s", "--max-time", "12",
            "https://music.youtube.com/youtubei/v1/search?prettyPrint=false",
            "-H", "Content-Type: application/json",
            "-H", "User-Agent: Mozilla/5.0",
            "--data-raw", YtMusic.innertubeBody(term)]
        stdout: StdioCollector { id: searchOut }
        onExited: (code, status) => {
            // killed = superseded by a newer term; never cache its partial body.
            if (status !== 0)
                return;
            var rows = code === 0 ? YtMusic.parse(searchOut.text) : [];
            if (rows.length > 0) {
                ytmusic.cachePut(searchProc.term, rows);
                Dispatcher.setBusy("ytmusic", false);
                Dispatcher.notifyAsync();
            } else {
                // InnerTube empty/unreachable: try the yt-dlp fallback.
                fallbackProc.term = searchProc.term;
                fallbackProc.out = "";
                fallbackProc.running = false;
                fallbackProc.running = true;
            }
        }
    }

    // Fallback: yt-dlp flat search (NDJSON), only when InnerTube yields nothing.
    Process {
        id: fallbackProc
        property string term: ""
        property string out: ""
        command: ["yt-dlp", "ytsearch12:" + term, "--flat-playlist", "-j", "--no-warnings"]
        stdout: SplitParser {
            onRead: line => fallbackProc.out += line + "\n"
        }
        onStarted: fallbackProc.out = ""
        onExited: (code, status) => {
            // killed = superseded. Non-zero = yt-dlp or network failure: clear
            // the spinner but cache nothing, so the same query retries instead
            // of pinning "no matches" until LRU eviction.
            if (status !== 0)
                return;
            if (code !== 0) {
                Dispatcher.setBusy("ytmusic", false);
                Dispatcher.notifyAsync();
                return;
            }
            ytmusic.cachePut(fallbackProc.term, YtMusic.parseFlat(fallbackProc.out));
            Dispatcher.setBusy("ytmusic", false);
            Dispatcher.notifyAsync();
        }
    }

    Component.onCompleted: {
        availProc.running = true;
        Dispatcher.register(ytmusic);
    }
    Component.onDestruction: Radio.stop()
}
