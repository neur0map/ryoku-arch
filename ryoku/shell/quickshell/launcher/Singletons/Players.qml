pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The real, controllable MPRIS players: the playerctld proxy removed and deduped
// by dbus name, so the now-playing card and the sources strip never show the same
// source twice. Shared by Launcher, NowPlaying and MediaSources so all three agree
// on what exists.
Singleton {
    id: root

    // playerctld is a PROXY that mirrors whatever is active (its identity copies
    // the real player's), so it must never be shown or counted, or it double-lists
    // the active source. Identify it by dbus name; everything else is a real player.
    function isProxy(p) {
        return p && String(p.dbusName || "").indexOf("playerctld") !== -1;
    }

    // Real controllable players: the proxy removed and deduped by dbusName, so the
    // card and the strip never show the same source twice.
    function realPlayers() {
        var list = Mpris.players.values;
        var out = [];
        if (!list)
            return out;
        var seen = {};
        for (var i = 0; i < list.length; i++) {
            var p = list[i];
            if (!p || root.isProxy(p))
                continue;
            var key = String(p.dbusName || p.identity || i);
            if (seen[key])
                continue;
            seen[key] = 1;
            out.push(p);
        }
        return out;
    }
}
