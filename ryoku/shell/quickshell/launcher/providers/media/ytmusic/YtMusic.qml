import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import "../../../Singletons"
import "ytmusic.js" as YtMusic
import "../.."

// YouTube Music provider: searches YouTube with yt-dlp and streams the picked
// track with mpv (audio only) over an IPC socket, the mpv-mpris pipeline. Routed
// by a dedicated prefix so a plain query never forks yt-dlp. Search is async +
// cached; playback spawns mpv (reaped on the next play, on hide, or when another
// media player starts). Availability-gated on yt-dlp + mpv. Browser cookies
// (--cookies-from-browser) lift the rate limit when a default browser is signed
// in. mpv-mpris makes the stream a first-class MPRIS player, so the now-playing
// card and transport control it like any other; it also yields the moment a
// different player (Spotify, a browser tab) starts, so two streams never overlap.
Provider {
    id: ytmusic

    providerId: "ytmusic"
    prefix: "@"
    defaultProvider: false

    property bool available: false
    property string cachedQuery: ""
    property var cachedRows: []
    property string pendingQuery: ""
    property string pendingVideoId: ""
    property string pendingTitle: ""

    readonly property string ipcSocket: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-ytmusic-mpv.sock"
    readonly property string browser: Quickshell.env("BROWSER") || "firefox"

    // Kill any previous mpv, wait for the socket to disappear, then start the
    // new stream. Sequencing kill -> play through killProc.onExited avoids the
    // race where an immediate spawn beat pkill and inherited (or was killed
    // alongside) the outgoing process, leaving a zombie or a dangling socket.
    function play(track) {
        pendingVideoId = track.id;
        pendingTitle = track.title;
        playProc.running = false;
        killProc.running = false;
        killProc.running = true;
    }

    // Stop our stream for good: clear the pending track first so killProc's
    // onExited does not treat this as a track change and respawn mpv.
    function stop() {
        pendingVideoId = "";
        pendingTitle = "";
        playProc.running = false;
        killProc.running = false;
        killProc.running = true;
    }

    // Whether some OTHER media player (Spotify, a browser tab, an app) is
    // playing right now. mpv-mpris publishes our own stream with identity
    // "mpv", so anything else playing means the user started different audio
    // and we should yield instead of stacking two streams.
    function otherPlaying() {
        var list = Mpris.players.values;
        if (!list)
            return false;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (p && p.isPlaying && String(p.identity || "").toLowerCase() !== "mpv")
                return true;
        }
        return false;
    }

    // While our mpv streams, watch for another player taking over and bow out.
    // Runs only during playback (playProc.running), so it costs nothing at rest.
    Timer {
        interval: 1000
        repeat: true
        running: playProc.running
        onTriggered: if (ytmusic.otherPlaying()) ytmusic.stop();
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
        // pkill only signals: poll until the process is really gone (up to ~1s)
        // before removing the socket, so playProc never lands on a stale one.
        command: ["sh", "-c",
            "pkill -f 'mpv.*ryoku-ytmusic-mpv\\.sock' 2>/dev/null; " +
            "i=0; while [ $i -lt 20 ] && pgrep -f 'mpv.*ryoku-ytmusic-mpv\\.sock' >/dev/null 2>&1; do sleep 0.05; i=$((i+1)); done; " +
            "rm -f " + ytmusic.ipcSocket + "; true"]
        onExited: {
            if (ytmusic.pendingVideoId.length === 0)
                return;
            playProc.videoId = ytmusic.pendingVideoId;
            playProc.title = ytmusic.pendingTitle;
            ytmusic.pendingVideoId = "";
            ytmusic.pendingTitle = "";
            playProc.running = true;
        }
    }

    Component.onCompleted: {
        availProc.running = true;
        Dispatcher.register(ytmusic);
    }
    Component.onDestruction: {
        killProc.running = true;
    }
}
