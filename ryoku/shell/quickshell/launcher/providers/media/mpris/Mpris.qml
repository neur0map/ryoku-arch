import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../../../Singletons"
import "../.."

// MPRIS provider: surfaces the active media player (Spotify, the YT Music PWA,
// a browser tab, mpv) as launcher rows. The now-playing row plus transport verbs
// appear when the query mentions media (play/pause/next/music...) or matches the
// current track, so a plain search stays clean. Control is direct D-Bus via the
// Quickshell Mpris service; no backend.
Provider {
    id: mpris

    providerId: "mpris"

    // Pick order mirrors the pill: playing > paused-with-track > controllable.
    readonly property var player: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        var withTrack = null;
        var controllable = null;
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p)
                continue;
            if (p.isPlaying)
                return p;
            if (!withTrack && p.canControl && p.trackTitle && p.trackTitle.length > 0)
                withTrack = p;
            if (!controllable && p.canControl)
                controllable = p;
        }
        return withTrack ? withTrack : (controllable ? controllable : list[0]);
    }

    readonly property var mediaWords: ["play", "pause", "next", "previous", "skip", "music", "media", "song", "track", "resume", "stop", "volume"]

    function nowPlayingRow() {
        var p = mpris.player;
        var artist = Theme.joinArtists(p.trackArtists, p.trackArtist);
        return {
            id: "mpris:now",
            title: p.trackTitle && p.trackTitle.length ? p.trackTitle : "Now playing",
            subtitle: artist.length ? artist : (p.identity || "Media"),
            icon: "",
            type: "Now Playing",
            score: 2,
            actions: [
                { name: p.isPlaying ? "Pause" : "Play", icon: "", execute: function () { if (p.canTogglePlaying) p.togglePlaying(); } },
                { name: "Next", icon: "", execute: function () { if (p.canGoNext) p.next(); } },
                { name: "Previous", icon: "", execute: function () { if (p.canGoPrevious) p.previous(); } }
            ]
        };
    }

    // Route the row on either a media verb (a query that equals a media word or
    // is a prefix of one) or the current track's title/artist. Substring on the
    // joined word list was wrong: a single common letter like `a`/`e` matched
    // any word containing it, leaking the row into unrelated searches.
    function matches(text) {
        var q = text.toLowerCase();
        for (var i = 0; i < mpris.mediaWords.length; i++) {
            if (mpris.mediaWords[i].indexOf(q) === 0)
                return true;
        }
        var p = mpris.player;
        var hay = ((p.trackTitle || "") + " " + Theme.joinArtists(p.trackArtists, p.trackArtist)).toLowerCase();
        return hay.indexOf(q) !== -1;
    }

    function query(text) {
        if (!mpris.player)
            return [];
        var t = (text || "").trim();
        if (t.length === 0)
            return [];
        if (!mpris.matches(t))
            return [];
        return [nowPlayingRow()];
    }

    Component.onCompleted: Dispatcher.register(mpris);
}
