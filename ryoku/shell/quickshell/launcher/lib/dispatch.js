// Search-text routing: a leading prefix (one or more chars) selects a provider
// and is stripped from the query; anything else fans out to the default
// providers. Longest prefix wins, so "s:" beats a hypothetical "s". Pure logic so
// the dispatcher's routing is unit-tested without a running shell.

function routePrefix(text, prefixes) {
    var s = String(text == null ? "" : text);
    if (prefixes) {
        var best = "";
        for (var p in prefixes) {
            if (p.length > 0 && s.indexOf(p) === 0 && p.length > best.length)
                best = p;
        }
        if (best.length > 0)
            return { provider: prefixes[best], query: s.slice(best.length).replace(/^\s+/, ""), prefix: best };
    }
    return { provider: null, query: s, prefix: "" };
}

// Whether the text reads as a calculation (leading digit), so an unprefixed
// numeric query surfaces the calculator alongside app results.
function looksNumeric(text) {
    return /^\s*\d/.test(String(text == null ? "" : text));
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { routePrefix, looksNumeric };
}
