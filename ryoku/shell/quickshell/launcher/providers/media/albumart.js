// Album-art lookup for the now-playing card when the MPRIS player supplies no
// trackArtUrl (mpv/yt-dlp streams, some browsers). Uses Apple's keyless iTunes
// Search API: results[0].artworkUrl100 is a 100x100 thumbnail whose URL swaps
// to 600x600 for a cover-sized image. Pure so parse/URL logic is node-tested
// without invoking curl. Consumed by NowPlaying.qml.

// Strip common video-title noise so the iTunes match lands on the actual song:
// bracketed tags ((Official Video), [HD], (Lyrics), (Audio)...), a trailing
// " - ..." or "feat./ft." credit, and collapsed whitespace. Applied to the
// fallback lookup for players whose titles carry this cruft (browsers).
function cleanTitle(s) {
    return String(s == null ? "" : s)
        .replace(/\([^)]*\)/g, " ")
        .replace(/\[[^\]]*\]/g, " ")
        .replace(/\s[-\u2013]\s.*$/i, " ")
        .replace(/\s(?:feat\.?|ft\.?|featuring)\s.*$/i, " ")
        .replace(/\s+/g, " ")
        .trim();
}

// Build the search URL for "artist title". Both fields are trimmed and the title
// is noise-stripped; if the combined term is empty (no artist, no title) return
// "" so callers can skip the fetch. If stripping empties the title (all tags),
// fall back to the raw title so the lookup still has something to match.
function searchUrl(artist, title) {
    var a = String(artist == null ? "" : artist).trim();
    var rawT = String(title == null ? "" : title).trim();
    var t = cleanTitle(rawT) || rawT;
    var term = (a && t) ? (a + " " + t) : (a || t);
    if (term.length === 0)
        return "";
    return "https://itunes.apple.com/search?term=" + encodeURIComponent(term) + "&entity=song&limit=1";
}

// Extract a large cover URL from an iTunes Search response body. Returns "" on
// any failure (null/empty text, malformed JSON, empty results, missing artwork)
// so the caller can fall through to the music-note glyph. The 100x100 -> 600x600
// swap is what iTunes intends for higher-res art; the CDN serves both.
function parseArt(rawJson) {
    if (rawJson == null)
        return "";
    var text = String(rawJson);
    if (text.length === 0)
        return "";
    var obj;
    try {
        obj = JSON.parse(text);
    } catch (e) {
        return "";
    }
    if (!obj || !obj.results || obj.results.length === 0)
        return "";
    var first = obj.results[0];
    if (!first || !first.artworkUrl100)
        return "";
    return String(first.artworkUrl100).replace("100x100", "600x600");
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { searchUrl, parseArt, cleanTitle };
}
