// Parse the `gpk search --json` envelope into launcher rows. The envelope is
// { gpk_version, schema, data: [{ name, version, source, description,
// installed, installed_at }] }. A package is installed when gpk says
// `installed: true` (schema-1 additive field); older gpk builds lack it, so a
// non-zero installed_at ("0001-01-01T00:00:00Z" means not installed) is the
// fallback. Pure logic so the provider's parsing is node-tested without gpk.

var ZERO_TIME = "0001-01-01T00:00:00Z";

function isInstalled(installedAt) {
    return typeof installedAt === "string" && installedAt.length > 0 && installedAt !== ZERO_TIME;
}

// Whether the running gpk supports the headless `search` envelope this provider
// needs (schema 1+). A missing/old gpk yields a non-conforming object.
function supportsSearch(envelope) {
    return !!envelope && typeof envelope.schema === "number" && envelope.schema >= 1 && Array.isArray(envelope.data);
}

function parse(raw) {
    var env;
    try {
        env = typeof raw === "string" ? JSON.parse(raw) : raw;
    } catch (e) {
        return [];
    }
    if (!supportsSearch(env))
        return [];
    var out = [];
    for (var i = 0; i < env.data.length; i++) {
        var p = env.data[i];
        if (!p || !p.name)
            continue;
        out.push({
            name: p.name,
            version: p.version || "",
            source: p.source || "",
            description: p.description || "",
            installed: p.installed === true || isInstalled(p.installed_at)
        });
    }
    return out;
}

if (typeof module !== "undefined" && module.exports) {
    module.exports = { parse, isInstalled, supportsSearch, ZERO_TIME };
}
