function statusLabels(item) {
    var labels = [];
    if (item && item.updateAvailable)
        labels.push("UPDATE");
    if (item && item.active)
        labels.push("ACTIVE");
    else if (item && item.enabled)
        labels.push("ENABLED");
    else if (item && Number(item.installedCount || 0) > 0 && Number(item.totalCount || 0) > 0)
        labels.push(String(item.installedCount) + " / " + String(item.totalCount) + " INSTALLED");
    else if (item && item.installed)
        labels.push("INSTALLED");
    else
        labels.push("AVAILABLE");
    return labels;
}

function isInstalled(item) {
    return Boolean(item && (item.installed || item.active || item.enabled || Number(item.installedCount || 0) > 0));
}

function searchText(item) {
    if (!item)
        return "";
    return [
        item.id,
        item.category,
        item.categoryName,
        item.name,
        item.summary,
        item.description,
        item.author,
        item.version,
        (item.tags || []).join(" "),
        statusLabels(item).join(" ")
    ].filter(Boolean).join(" ").toLowerCase();
}

function matchesQuery(item, query) {
    var terms = String(query || "").trim().toLowerCase().split(/\s+/).filter(Boolean);
    if (terms.length === 0)
        return true;
    var haystack = searchText(item);
    return terms.every(function(term) { return haystack.indexOf(term) !== -1; });
}

function filter(items, options) {
    var source = Array.isArray(items) ? items : [];
    var opts = options || {};
    return source.filter(function(item) {
        if (opts.category && item.category !== opts.category)
            return false;
        if (opts.installedOnly && !isInstalled(item))
            return false;
        if (opts.updatesOnly && !item.updateAvailable)
            return false;
        if (opts.provider && (item.metadata && item.metadata.provider ? item.metadata.provider : "Community") !== opts.provider)
            return false;
        if (opts.tag && (item.tags || []).indexOf(opts.tag) === -1)
            return false;
        return matchesQuery(item, opts.query);
    });
}

function groupSearch(items, query) {
    return filter(items, { query: query });
}

function featured(items) {
    var source = Array.isArray(items) ? items : [];
    for (var i = 0; i < source.length; i++)
        if (!source[i].sourceError && source[i].art && !isInstalled(source[i]))
            return source[i];
    for (var j = 0; j < source.length; j++)
        if (!source[j].sourceError && source[j].art)
            return source[j];
    for (var k = 0; k < source.length; k++)
        if (!source[k].sourceError)
            return source[k];
    return null;
}

function installed(items) {
    return (Array.isArray(items) ? items : []).filter(isInstalled);
}

function itemKey(item) {
    return item ? String(item.category || "") + ":" + String(item.id || "") : "";
}

function collection(items, options) {
    var opts = options || {};
    var filtered = filter(items, {
        category: opts.categoryID || "",
        installedOnly: opts.view === "library" || opts.installedOnly === true,
        provider: opts.provider || "",
        query: opts.query || ""
    });
    if (opts.view !== "library" && !opts.categoryID && !opts.query) {
        var lead = featured(filtered);
        return lead ? [lead].concat(filtered.filter(function(item) { return itemKey(item) !== itemKey(lead); })) : filtered;
    }
    return filtered;
}

function selectionKey(items, requestedKey, fallbackIndex) {
    var source = Array.isArray(items) ? items : [];
    for (var i = 0; i < source.length; i++)
        if (itemKey(source[i]) === requestedKey)
            return requestedKey;
    if (source.length === 0)
        return "";
    var index = Math.max(0, Math.min(source.length - 1, Number(fallbackIndex || 0)));
    return itemKey(source[index]);
}

function categoryPlates(categories) {
    return (Array.isArray(categories) ? categories : []).map(function(category) {
        var copy = {};
        Object.keys(category).forEach(function(key) { copy[key] = category[key]; });
        return copy;
    });
}

function primaryAction(item) {
    if (item && item.busy)
        return "INSTALLING";
    if (item && Number(item.installedCount || 0) > 0 && Number(item.totalCount || 0) > Number(item.installedCount || 0))
        return "INSTALL " + String(Number(item.totalCount) - Number(item.installedCount)) + " ITEMS";
    return isInstalled(item) ? "INSTALLED" : "INSTALL";
}

function secondaryAction(item) {
    return (item && item.hasSettings && isInstalled(item)) ? "OPEN IN SETTINGS" : "";
}

function sortCategories(categories) {
    var rank = { find: 0, wear: 1, extend: 2 };
    return (Array.isArray(categories) ? categories : []).map(function(category, index) {
        return { category: category, index: index };
    }).sort(function(a, b) {
        var ar = Object.prototype.hasOwnProperty.call(rank, a.category.group) ? rank[a.category.group] : 99;
        var br = Object.prototype.hasOwnProperty.call(rank, b.category.group) ? rank[b.category.group] : 99;
        return ar - br || a.index - b.index;
    }).map(function(row) { return row.category; });
}

if (typeof module !== "undefined" && module.exports)
    module.exports = { statusLabels, isInstalled, searchText, matchesQuery, filter, groupSearch, featured, installed, itemKey, collection, selectionKey, categoryPlates, primaryAction, secondaryAction, sortCategories };
