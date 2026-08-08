
function stable(nodes, prevName, fallback) {
    var list = Array.isArray(nodes) ? nodes : [];
    if (prevName) {
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].name === prevName) return list[i];
    }
    if (fallback) {
        for (var j = 0; j < list.length; j++)
            if (list[j] && list[j].name === fallback.name) return list[j];
        return fallback;
    }
    return list.length ? list[0] : null;
}

if (typeof module !== "undefined" && module.exports) module.exports = { stable };
