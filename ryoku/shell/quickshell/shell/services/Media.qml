pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// the one now-playing pick every surface shares: prefers a sounding player,
// falls back to the first real one. the live wallpaper (mpvpaper) registers
// on MPRIS too; a bare video filename is scenery, not music, so it never
// counts as a player here.
Singleton {
    id: root

    function isWallpaper(p) {
        return /\.(mp4|webm|mkv|gif)$/i.test(p.trackTitle || "");
    }
    // the ryoku live radio (launcher "@"): an mpv whose forced title carries
    // the LIVE prefix. Same signature the launcher matches on — a broadcast
    // gets a tally lamp instead of a seek bar (it has no position to show).
    function isRadio(p) {
        return !!p && String(p.dbusName || "").indexOf(".mpv") !== -1
            && String(p.trackTitle || "").indexOf("LIVE · ") === 0;
    }

    function pick(players) {
        var list = players.filter(function(p) { return p && !root.isWallpaper(p); });
        for (var i = 0; i < list.length; i++)
            if (list[i].isPlaying)
                return list[i];
        for (var j = 0; j < list.length; j++)
            if ((list[j].trackTitle || "").length > 0)
                return list[j];
        return list.length > 0 ? list[0] : null;
    }
    readonly property var player: root.pick(Mpris.players.values)
    readonly property bool playing: player !== null && player.isPlaying
    readonly property bool present: player !== null && (player.trackTitle || "").length > 0
    readonly property bool radio: player !== null && isRadio(player)
    readonly property string line: {
        if (!player)
            return "";
        var t = player.trackTitle || "";
        var a = Theme.joinArtists(player.trackArtists, player.trackArtist);
        return a.length > 0 ? t + " · " + a : t;
    }

    function toggle() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }
}
