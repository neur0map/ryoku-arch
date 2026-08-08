
function count(groups) {
    var list = Array.isArray(groups) ? groups : [];
    var total = 0;
    for (var i = 0; i < list.length; i++) {
        var g = list[i];
        total += (g && typeof g.count === "number") ? g.count : 0;
    }
    return total;
}

function rows(groups) {
    var list = Array.isArray(groups) ? groups : [];
    var out = [];
    for (var i = 0; i < list.length; i++) {
        var g = list[i] || {};
        var p = g.preview || {};
        out.push({
            app: (g.app && g.app.length) ? g.app : "System",
            count: typeof g.count === "number" ? g.count : 0,
            summary: p.summary || "",
            body: p.body || ""
        });
    }
    return out;
}

if (typeof module !== "undefined" && module.exports) module.exports = { count, rows };
