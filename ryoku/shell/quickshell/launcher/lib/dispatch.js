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

// Whether the text reads as a calculation, so an unprefixed numeric-looking
// query surfaces the calculator alongside app results. Kept conservative: a
// digit somewhere in the string is NOT enough (e.g. "route66" is an app name);
// only a leading digit, decimal, unary sign, parenthesis, or a known math token
// counts.
var NUMERIC_HEAD = /^(?:\d|\.\d|[+\-](?:\d|\.\d|\()|\()/;
var MATH_HEAD = /^(?:sqrt|asin|acos|atan|sin|cos|tan|log2|log10|log|ln|exp|abs|floor|ceil|round|factorial|degrees|radians|hypot|pow|tau|pi|e)(?:\(|\b)/;
function looksNumeric(text) {
    var s = String(text == null ? "" : text).replace(/^\s+/, "");
    if (s.length === 0)
        return false;
    if (NUMERIC_HEAD.test(s))
        return true;
    // A math token must be followed by "(" (a call) or a word boundary
    // (a constant like `pi*2`). Guards against words like "sine" or "expert".
    return MATH_HEAD.test(s);
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { routePrefix, looksNumeric };
}
