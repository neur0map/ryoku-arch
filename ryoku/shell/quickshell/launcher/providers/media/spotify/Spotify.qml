import QtQuick
import Quickshell
import Quickshell.Io
import "../../../Singletons"
import "../../packages/gpk.js" as Envelope
import "../.."

// Spotify catalog provider: searches the Spotify Web API via the
// `ryoku-shell spotify search` subcommand (which owns the OAuth token), so secrets
// never touch QML. Routed by the "s:" prefix so a plain query never hits the API;
// the MPRIS provider already controls the running Spotify client. Play sends the
// track to the active device through the same subcommand (Premium required).
// Hidden until the user has authenticated (`ryoku-shell spotify auth <client-id>`).
Provider {
    id: spotify

    providerId: "spotify"
    prefix: "s:"
    defaultProvider: false

    property bool authed: false
    property string cachedQuery: ""
    property var cachedRows: []
    property string pendingQuery: ""

    // The subcommand emits { schema, data:[{title, subtitle, uri, id}] }; the
    // gpk envelope check (schema>=1 + data array) fits this shape too, so reuse it.
    function parseTracks(raw) {
        try {
            var env = JSON.parse(raw);
            if (!Envelope.supportsSearch(env))
                return [];
            return env.data;
        } catch (e) {
            return [];
        }
    }

    function rowFor(track) {
        return {
            id: "spotify:" + track.id,
            title: track.title,
            subtitle: track.subtitle,
            icon: "",
            type: "Spotify",
            score: 0,
            actions: [
                { name: "Play", icon: "", execute: function () { playProc.uri = track.uri; playProc.running = false; playProc.running = true; } },
                { name: "Open", icon: "", execute: function () { Qt.openUrlExternally("https://open.spotify.com/track/" + track.id); } }
            ]
        };
    }

    function query(text) {
        if (!spotify.authed)
            return [];
        var t = (text || "").trim();
        if (t.length < 2)
            return [];
        if (t === spotify.cachedQuery)
            return spotify.cachedRows.map(spotify.rowFor);
        spotify.pendingQuery = t;
        debounce.restart();
        return [];
    }

    Timer {
        id: debounce
        interval: 200
        repeat: false
        onTriggered: {
            searchProc.term = spotify.pendingQuery;
            searchProc.running = false;
            searchProc.running = true;
        }
    }

    // Authenticated when the token file exists; the subcommand writes it on auth.
    FileView {
        id: tokenFile
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/spotify-token.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: spotify.authed = tokenFile.text().length > 0
        onFileChanged: reload()
    }

    Process {
        id: searchProc
        onRunningChanged: Dispatcher.setBusy("spotify", running)
        property string term: ""
        property string out: ""
        command: ["ryoku-shell", "spotify", "search", term]
        stdout: SplitParser {
            onRead: line => searchProc.out += line + "\n"
        }
        onStarted: searchProc.out = ""
        onExited: {
            spotify.cachedQuery = searchProc.term;
            spotify.cachedRows = spotify.parseTracks(searchProc.out);
            Dispatcher.notifyAsync();
        }
    }

    Process {
        id: playProc
        property string uri: ""
        command: ["ryoku-shell", "spotify", "play", uri]
    }

    Component.onCompleted: {
        spotify.authed = tokenFile.text().length > 0;
        Dispatcher.register(spotify);
    }
}
