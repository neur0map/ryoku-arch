// Live-radio logic for the "@" prefix: which station rows a query surfaces,
// what the primary verb on each is, and how a radio mpv is told apart from
// every other player. Pure functions so the routing and the player match are
// unit-tested without a running shell.

// The engine titles its mpv "LIVE · <station>"; that prefix plus an mpv D-Bus
// name is the radio's signature. Title alone is not enough (any player could
// carry it) and mpv alone is not enough (live wallpapers and plain mpv use are
// mpv too).
var TITLE_PREFIX = "LIVE · ";

function isRadioTitle(title) {
    return String(title == null ? "" : title).indexOf(TITLE_PREFIX) === 0;
}

function isRadioPlayer(dbusName, title) {
    var d = String(dbusName == null ? "" : dbusName);
    return d.indexOf(".mpv") !== -1 && isRadioTitle(title);
}

// A live wallpaper is an mpv too (mpvpaper / livewall): a video-file title, no
// radio prefix. The collision watcher must never count one as "music started".
var WALLPAPER_RE = /\.(mp4|webm|mkv|mov|gif)$/i;
function isWallpaperTitle(title) {
    return WALLPAPER_RE.test(String(title == null ? "" : title));
}

// What the collision watcher counts as music: a player with a real track
// title. No title yet (a player still registering — the radio's own mpv sits
// titleless for a beat mid-tune-in and must not assassinate itself), the
// radio's own LIVE prefix, wallpaper scenery, and bare URL titles (a stream
// still resolving) all don't count; the moment a real title lands, the
// binding re-reads it and the verdict updates.
var URLISH_RE = /^(https?:\/\/|www\.)/i;
function countsAsMusic(title) {
    var t = String(title == null ? "" : title);
    if (t.length === 0)
        return false;
    if (isRadioTitle(t) || WALLPAPER_RE.test(t) || URLISH_RE.test(t))
        return false;
    return true;
}

// The station rows the "@" query surfaces. `stations` come from the engine
// (`ryoku-cmd-radio stations`), `status` from its `status` verb. Empty query
// lists everything (playing station first); text narrows by id/label
// substring. Each row carries the right primary verb for its state:
// stop (it is on air), resume (it was set aside), start (silent).
function stationRows(stations, query, status) {
    var q = String(query == null ? "" : query).trim().toLowerCase();
    var st = status || {};
    var rows = [];
    var list = stations || [];
    for (var i = 0; i < list.length; i++) {
        var s = list[i];
        if (!s || !s.id)
            continue;
        var hay = (s.id + " " + (s.label || "")).toLowerCase();
        if (q.length > 0 && hay.indexOf(q) === -1)
            continue;
        var on = st.on === true && st.station === s.id;
        var aside = !on && st.aside && st.aside.station === s.id;
        rows.push({
            id: s.id,
            label: s.label || s.id,
            on: on,
            verb: on ? "stop" : (aside ? "resume" : "start"),
            // the fallback is part of the promise: say it up front. And while
            // the stream still resolves (state on, no player yet) the silence
            // must read as tuning, not as a broken start.
            note: on
                ? (st.tuning === true ? "tuning in — a few quiet seconds is normal"
                    : (st.fellBack === true ? "on air · fallback station" : "on air"))
                : (aside ? "set aside — resume picks it back up"
                    : (s.fallback ? "live radio · falls back to " + s.fallback : "live radio")),
            score: on ? -20 : (aside ? -15 : i)
        });
    }
    rows.sort(function (a, b) { return a.score - b.score; });
    return rows;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { isRadioTitle, isRadioPlayer, isWallpaperTitle, countsAsMusic, stationRows, TITLE_PREFIX };
}
