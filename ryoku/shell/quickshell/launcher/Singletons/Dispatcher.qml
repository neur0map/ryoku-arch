pragma Singleton
import QtQuick
import Quickshell
import "../lib/dispatch.js" as Dispatch

// Routes a search query to providers. A leading prefix char selects one provider;
// an unprefixed query fans across every default provider, merged by score and
// capped. Providers register themselves on load, so adding one never edits here.
Singleton {
    id: root

    property var registry: ({})   // id -> provider instance
    property var prefixes: ({})   // prefix char -> provider id
    function register(provider) {
        if (!provider || !provider.providerId)
            return;
        root.registry[provider.providerId] = provider;
        var p = root.prefixes;
        if (provider.prefix && provider.prefix.length >= 1)
            p[provider.prefix] = provider.providerId;
        // a provider may claim several prefixes (e.g. find: /file /folder /image
        // /video); each routes to it, and query() gets the matched prefix as mode.
        var extra = provider.prefixes || [];
        for (var i = 0; i < extra.length; i++)
            p[extra[i]] = provider.providerId;
        root.prefixes = p;
    }

    // The provider a prefixed query targets, or "" for the default fan-out.
    function route(text) {
        return Dispatch.routePrefix(text, root.prefixes);
    }

    // Bumped by async providers when a background query resolves; the launcher's
    // results binding reads it so a late result (qalc, fd, gpk, music) repaints
    // without the user retyping.
    property int revision: 0
    function notifyAsync() { root.revision++; }

    // In-flight async providers, keyed by id so begin/end calls are idempotent
    // and several can run at once. `busy` is true while any is searching; the
    // launcher reads it to show a spinner instead of a premature "No matches".
    property var busyProviders: ({})
    property int busyRevision: 0
    readonly property bool busy: { void root.busyRevision; return Object.keys(root.busyProviders).length > 0; }
    function setBusy(id, on) {
        var b = root.busyProviders;
        if (on) b[id] = true; else delete b[id];
        root.busyProviders = b;
        root.busyRevision++;
    }

    // Merged, score-sorted, capped result rows for the current query. Reads
    // `revision` so async caches re-pull on resolve.
    function results(text, limit) {
        void root.revision;
        var r = Dispatch.routePrefix(text, root.prefixes);
        var rows = [];
        if (r.provider) {
            var p = root.registry[r.provider];
            if (p)
                rows = p.query(r.query, r.prefix);
        } else {
            for (var id in root.registry) {
                var prov = root.registry[id];
                if (prov && prov.defaultProvider)
                    rows = rows.concat(prov.query(r.query));
                else if (prov && prov.numericFallback && Dispatch.looksNumeric(r.query))
                    rows = rows.concat(prov.query(r.query));
            }
            rows.sort(function (a, b) {
                return (a.score || 0) - (b.score || 0);
            });
        }
        var cap = limit && limit > 0 ? limit : rows.length;
        return rows.length > cap ? rows.slice(0, cap) : rows;
    }
}
