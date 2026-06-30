import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Singletons"
import "ytmusic.js" as YtMusic
import "../.."

// YouTube Music provider: searches YouTube with yt-dlp and streams the picked
// track with mpv (audio only) over an IPC socket, the inir pipeline. Routed by a
// dedicated prefix so a plain query never forks yt-dlp. Search is async + cached;
// playback spawns mpv (reaped on the next play / on hide). Availability-gated on
// yt-dlp + mpv. Browser cookies (--cookies-from-browser) lift the rate limit when
// a default browser is signed in.
Provider {
    id: ytmusic

    providerId: "ytmusic"
    prefix: "@"
    defaultProvider: false

    property bool available: false
    property string cachedQuery: ""
    property var cachedRows: []
    property string pendingQuery: ""

    readonly property string ipcSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-ytmusic-mpv.sock"
    readonly property string browser: Quickshell.env("BROWSER") || "firefox"

    function play(track) {
        // Stop any current stream, then start mpv on the track's audio. mpv
        // resolves the stream URL itself via yt-dlp (ytdl_hook).
        killProc.running = false;
        killProc.running = true;
        playProc.videoId = track.id;
        playProc.title = track.title;
        playProc.running = false;
        playProc.running = true;
    }

    function rowFor(track) {
        return {
            id: "ytm:" + track.id,
            title: track.title,
            subtitle: (track.artist ? track.artist : "YouTube Music") + (track.durationLabel ? "  " + track.durationLabel : ""),
            icon: "",
            type: "YT Music",
            score: 0,
            actions: [
                { name: "Play", icon: "", execute: function () { ytmusic.play(track); } },
                { name: "Open", icon: "", execute: function () { Qt.openUrlExternally("https://music.youtube.com/watch?v=" + track.id); } }
            ]
        };
    }

    function query(text) {
        if (!ytmusic.available)
            return [];
        var t = (text || "").trim();
        if (t.length < 2)
            return [];
        if (t === ytmusic.cachedQuery)
            return ytmusic.cachedRows.map(ytmusic.rowFor);
        ytmusic.pendingQuery = t;
        debounce.restart();
        return [];
    }

    Timer {
        id: debounce
        interval: 200
        repeat: false
        onTriggered: {
            searchProc.term = ytmusic.pendingQuery;
            searchProc.running = false;
            searchProc.running = true;
        }
    }

    Process {
        id: availProc
        command: ["sh", "-c", "command -v yt-dlp >/dev/null 2>&1 && command -v mpv >/dev/null 2>&1"]
        onExited: (code) => { ytmusic.available = (code === 0); }
    }

    Process {
        id: searchProc
        onRunningChanged: Dispatcher.setBusy("ytmusic", running)
        property string term: ""
        property string out: ""
        command: ["yt-dlp", "ytsearch12:" + term, "--flat-playlist", "-j", "--no-warnings"]
        stdout: SplitParser {
            onRead: line => ytmusic.searchAppend(line)
        }
        onStarted: searchProc.out = ""
        onExited: {
            ytmusic.cachedQuery = searchProc.term;
            ytmusic.cachedRows = YtMusic.parse(searchProc.out);
            Dispatcher.notifyAsync();
        }
    }

    function searchAppend(line) {
        searchProc.out += line + "\n";
    }

    Process {
        id: playProc
        property string videoId: ""
        property string title: ""
        command: ["mpv", "--no-video", "--force-window=no", "--audio-display=no",
            "--input-ipc-server=" + ytmusic.ipcSocket,
            "--ytdl-format=bestaudio",
            "--force-media-title=" + title,
            "https://music.youtube.com/watch?v=" + videoId]
    }

    Process {
        id: killProc
        command: ["sh", "-c", "pkill -f 'mpv.*ryoku-ytmusic-mpv\\.sock' 2>/dev/null; rm -f " + ytmusic.ipcSocket + "; true"]
    }

    Component.onCompleted: {
        availProc.running = true;
        Dispatcher.register(ytmusic);
    }
    Component.onDestruction: {
        killProc.running = true;
    }
}
