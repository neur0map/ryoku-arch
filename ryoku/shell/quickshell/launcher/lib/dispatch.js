// Search-text routing: a leading prefix char selects a provider and is stripped
// from the query; anything else fans out to the default providers. Pure logic so
// the dispatcher's routing is unit-tested without a running shell.

function routePrefix(text, prefixes) {
    var s = String(text == null ? "" : text);
    var head = s.charAt(0);
    if (head && prefixes && Object.prototype.hasOwnProperty.call(prefixes, head))
        return { provider: prefixes[head], query: s.slice(1).replace(/^\s+/, "") };
    return { provider: null, query: s };
}

// Whether the text reads as a calculation (leading digit), so an unprefixed
// numeric query surfaces the calculator alongside app results.
function looksNumeric(text) {
    return /^\s*\d/.test(String(text == null ? "" : text));
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { routePrefix, looksNumeric };
}
