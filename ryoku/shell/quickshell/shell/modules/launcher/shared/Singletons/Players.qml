pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The real, controllable MPRIS players: playerctld is removed and D-Bus names
// are deduplicated. The searchable MPRIS provider and radio collision minder
// share this view of what exists.
Singleton {
    id: root

    // playerctld is a PROXY that mirrors whatever is active (its identity copies
    // the real player's), so it must never be shown or counted, or it double-lists
    // the active source. Identify it by dbus name; everything else is a real player.
    function isProxy(p) {
        return p && String(p.dbusName || "").indexOf("playerctld") !== -1;
    }

    // Real controllable players, with the proxy removed and D-Bus names unique.
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
