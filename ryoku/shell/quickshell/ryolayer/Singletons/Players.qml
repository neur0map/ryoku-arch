pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// The MPRIS field for the music widget: every real player (the playerctld
// proxy deduplicated, mirroring the launcher's rule), and the one to show:
// the playing player, else the first that can play.
Singleton {
    id: root

    readonly property var list: {
        var out = [];
        var vals = Mpris.players.values;
        for (var i = 0; i < vals.length; i++) {
            var p = vals[i];
            if (!p || !p.dbusName)
                continue;
            if (p.dbusName.indexOf("playerctld") !== -1)
                continue;
            out.push(p);
        }
        return out;
    }

    readonly property var active: {
        for (var i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        return list.length > 0 ? list[0] : null;
    }
}
