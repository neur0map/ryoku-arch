import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Single source of truth for "which player is active".
// The bar widget and the panel both instantiate this, so they can never
// disagree about the current player.
//
// playerctld (and the dead apps it proxies) can leave ghost entries that
// report Stopped or carry no metadata. Treat those as "no player".
QtObject {
    id: sel

    // playerctld is an aggregator proxy: it mirrors the last player and
    // freezes its state (often "Playing") once that player quits, leaving a
    // ghost entry. Real players always appear under their own bus name too,
    // so skip the proxy entirely and let the real entry win.
    function isProxy(p) {
        var n = (p.dbusName || "") + " " + (p.identity || "")
        return /playerctld/i.test(n)
    }

    function isReal(p) {
        if (!p) return false
        if (isProxy(p)) return false
        if (p.playbackState === MprisPlaybackState.Stopped) return false
        var hasMeta = (p.trackTitle && p.trackTitle.length > 0)
        return hasMeta || p.playbackState === MprisPlaybackState.Playing
    }

    readonly property var player: {
        var vals = Mpris.players.values
        var paused = null
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i]
            if (!isReal(p)) continue
            if (p.playbackState === MprisPlaybackState.Playing) return p
            if (p.playbackState === MprisPlaybackState.Paused && paused === null) paused = p
        }
        return paused
    }

    readonly property bool active:  player !== null
    readonly property bool playing: player !== null && player.playbackState === MprisPlaybackState.Playing
}
