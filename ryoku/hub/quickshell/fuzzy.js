.pragma library

// A small subsequence fuzzy scorer: every query character must appear in order.
// Consecutive matches, word starts, and the very first character score higher so
// "clw" ranks "Close window" above an incidental scatter. Returns -1 for no match.
function score(query, text) {
    if (!query)
        return 0;
    query = query.toLowerCase();
    text = text.toLowerCase();
    var qi = 0, streak = 0, prev = -2, total = 0;
    for (var ti = 0; ti < text.length && qi < query.length; ti++) {
        if (text.charAt(ti) === query.charAt(qi)) {
            var bonus = 1;
            if (ti === prev + 1) {
                streak += 1;
                bonus += streak * 3;
            } else {
                streak = 0;
            }
            var pc = ti > 0 ? text.charAt(ti - 1) : " ";
            if (pc === " " || pc === "+")
                bonus += 6;
            if (ti === 0)
                bonus += 8;
            total += bonus;
            prev = ti;
            qi += 1;
        }
    }
    return qi === query.length ? total : -1;
}

// rank flattens every bind across categories, scores it against the query (over
// its description and its keys), keeps the matches and returns them best-first,
// each tagged with its source category.
function rank(query, cats) {
    var out = [];
    if (!cats)
        return out;
    for (var i = 0; i < cats.length; i++) {
        var binds = cats[i].binds || [];
        for (var j = 0; j < binds.length; j++) {
            var b = binds[j];
            var keyStr = b.keys ? b.keys.join(" ") : "";
            var s = Math.max(score(query, b.desc), score(query, keyStr));
            if (s >= 0)
                out.push({ keys: b.keys, desc: b.desc, cat: cats[i].name, score: s });
        }
    }
    out.sort(function (a, b) { return b.score - a.score; });
    return out;
}
