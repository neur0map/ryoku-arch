function text(value) {
    return String(value == null ? "" : value);
}

function textList(value) {
    if (Array.isArray(value))
        return value.map(text);
    return value == null ? [] : [text(value)];
}

function scriptRowId(keyword, row) {
    var source = row || {};
    return "script:" + JSON.stringify([
        text(keyword),
        text(source.info),
        text(source.text)
    ]);
}

function snippetRowId(entry) {
    var source = entry || {};
    if (text(source.id).length > 0)
        return "snippet:" + JSON.stringify(["id", text(source.id)]);
    return "snippet:" + JSON.stringify([
        "content",
        text(source.name),
        text(source.keyword),
        text(source.body),
        textList(source.keywords)
    ]);
}

function quicklinkRowId(entry) {
    var source = entry || {};
    if (text(source.id).length > 0)
        return "quicklink:" + JSON.stringify(["id", text(source.id)]);
    return "quicklink:" + JSON.stringify([
        "content",
        text(source.name),
        text(source.keyword),
        text(source.url),
        textList(source.keywords)
    ]);
}

function dedupeRows(rows) {
    var source = Array.isArray(rows) ? rows : [];
    var seen = {};
    var out = [];
    for (var index = 0; index < source.length; index++) {
        var row = source[index];
        if (!row || text(row.id).length === 0)
            continue;
        var key = "$" + text(row.id);
        if (seen[key])
            continue;
        seen[key] = true;
        out.push(row);
    }
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = {
        dedupeRows: dedupeRows,
        quicklinkRowId: quicklinkRowId,
        scriptRowId: scriptRowId,
        snippetRowId: snippetRowId
    };
}
