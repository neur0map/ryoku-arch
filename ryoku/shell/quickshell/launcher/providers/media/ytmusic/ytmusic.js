// Parse yt-dlp's flat-playlist NDJSON (one JSON object per line, from
// `yt-dlp ytsearchN:query --flat-playlist -j`) into track rows, filtering out
// non-songs by duration. Pure so the parse + filter is node-tested without
// invoking yt-dlp. Consumed by YtMusic.qml.

var MIN_SEC = 30;     // drop clips/intros
var MAX_SEC = 600;    // drop long-form (podcasts, mixes, full albums)

function fmtDuration(sec) {
    if (!(sec > 0))
        return "";
    var s = Math.floor(sec);
    var m = Math.floor(s / 60);
    var r = s % 60;
    return m + ":" + (r < 10 ? "0" + r : r);
}

// Parse NDJSON text into { id, title, artist, duration, durationLabel } tracks,
// keeping only plausible songs (MIN_SEC..MAX_SEC). Malformed lines are skipped.
function parse(text) {
    var lines = String(text == null ? "" : text).split("\n");
    var out = [];
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.length === 0)
            continue;
        var o;
        try {
            o = JSON.parse(line);
        } catch (e) {
            continue;
        }
        if (!o || !o.id || !o.title)
            continue;
        var dur = typeof o.duration === "number" ? o.duration : 0;
        if (dur > 0 && (dur < MIN_SEC || dur > MAX_SEC))
            continue;
        out.push({
            id: o.id,
            title: o.title,
            artist: o.uploader || o.channel || o.artist || "",
            duration: dur,
            durationLabel: fmtDuration(dur)
        });
    }
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parse, fmtDuration, MIN_SEC, MAX_SEC };
}
