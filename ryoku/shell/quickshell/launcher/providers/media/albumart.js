// Album-art lookup for the now-playing card when the MPRIS player supplies no
// trackArtUrl (mpv/yt-dlp streams, some browsers). Uses Apple's keyless iTunes
// Search API: results[0].artworkUrl100 is a 100x100 thumbnail whose URL swaps
// to 600x600 for a cover-sized image. Pure so parse/URL logic is node-tested
// without invoking curl. Consumed by NowPlaying.qml.

// Build the search URL for "artist title". Both fields are trimmed; if the
// combined term is empty (no artist, no title) return "" so callers can skip
// the fetch instead of hammering the API with a blank query.
function searchUrl(artist, title) {
    var a = String(artist == null ? "" : artist).trim();
    var t = String(title == null ? "" : title).trim();
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
    module.exports = { searchUrl, parseArt };
}
