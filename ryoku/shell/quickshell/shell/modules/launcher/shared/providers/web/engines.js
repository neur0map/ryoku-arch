// Web-search routing: a leading "!bang" picks a site, otherwise the default
// engine is used. Pure URL/bang logic so the web provider's behavior is tested
// without opening a browser. Consumed by Web.qml (QML import) and node tests.

var ENGINES = {
    g:  { name: "Google",     url: "https://www.google.com/search?q=" },
    ddg:{ name: "DuckDuckGo", url: "https://duckduckgo.com/?q=" },
    yt: { name: "YouTube",    url: "https://www.youtube.com/results?search_query=" },
    gh: { name: "GitHub",     url: "https://github.com/search?q=" },
    w:  { name: "Wikipedia",  url: "https://en.wikipedia.org/w/index.php?search=" },
    aur:{ name: "AUR",        url: "https://aur.archlinux.org/packages?K=" },
    npm:{ name: "npm",        url: "https://www.npmjs.com/search?q=" }
};

// Split a leading "!bang" off the query. Returns { bang, query } with bang ""
// when none. The bang must be the first whitespace-delimited token.
function parseBang(text) {
    var s = String(text == null ? "" : text).trim();
    var m = s.match(/^!(\S+)\s*(.*)$/);
    if (m)
        return { bang: m[1].toLowerCase(), query: m[2] };
    return { bang: "", query: s };
}

// Resolve a query to a search URL. A known bang selects its engine; an unknown
// bang falls back to the default engine searching the whole text. The query is
// percent-encoded.
function buildUrl(text, defaultKey) {
    var parsed = parseBang(text);
    var key = parsed.bang && ENGINES[parsed.bang] ? parsed.bang : (defaultKey || "g");
    var query = parsed.bang && ENGINES[parsed.bang] ? parsed.query : String(text == null ? "" : text).trim();
    return ENGINES[key].url + encodeURIComponent(query);
}

// Human label for the engine a query would hit, for the result subtitle.
function engineName(text, defaultKey) {
    var parsed = parseBang(text);
    var key = parsed.bang && ENGINES[parsed.bang] ? parsed.bang : (defaultKey || "g");
    return ENGINES[key].name;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { ENGINES, parseBang, buildUrl, engineName };
}
