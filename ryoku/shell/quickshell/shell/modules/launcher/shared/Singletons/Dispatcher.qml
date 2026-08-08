pragma Singleton
import QtQuick
import Quickshell
import "../lib/dispatch.js" as Dispatch
import "../lib/results.js" as Results

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
        root.notifyAsync();
    }

    // The provider a prefixed query targets, or "" for the default fan-out.
    function route(text) {
        return Dispatch.routePrefix(text, root.prefixes);
    }

    // Bumped whenever provider-visible state changes. The launcher coalesces
    // revisions into imperative snapshots, so late async rows and model changes
    // repaint without putting impure provider queries inside a QML binding.
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

    function capped(rows, limit) {
        var cap = limit && limit > 0 ? limit : rows.length;
        return rows.length > cap ? rows.slice(0, cap) : rows;
    }

    function providerRows(providerId, query, prefix) {
        var provider = root.registry[providerId];
        if (!provider)
            return [];

        var raw;
        if (providerId === "apps" && String(query || "").length === 0
                && typeof provider.allRows === "function")
            raw = provider.allRows();
        else
            raw = provider.query(query, prefix);
        return Results.normalizeRows(providerId, raw);
    }

    // Internal modes call this directly, so IMG/FILE can pass their provider
    // mode without putting a synthetic prefix into the visible query. A null
    // provider fans out exactly like an ordinary unprefixed search.
    function resultsFor(providerId, query, prefix, limit) {
        void root.revision;
        var requested = providerId || "";
        if (requested.length > 0)
            return root.capped(root.providerRows(requested, query, prefix), limit);

        var decorated = [];
        var order = 0;
        for (var id in root.registry) {
            var provider = root.registry[id];
            if (!provider)
                continue;
            var include = provider.defaultProvider
                || (provider.numericFallback && Dispatch.looksNumeric(query));
            if (!include)
                continue;

            var normalized = Results.normalizeRows(id, provider.query(query));
            for (var index = 0; index < normalized.length; index++)
                decorated.push({ row: normalized[index], order: order++ });
        }

        // QV4's Array.sort is not stable. Keep provider emission order as the
        // explicit tie-break without leaking an implementation field into rows.
        decorated.sort(function (a, b) {
            var score = (a.row.score || 0) - (b.row.score || 0);
            return score !== 0 ? score : a.order - b.order;
        });

        var rows = decorated.map(function (entry) { return entry.row; });
        return root.capped(rows, limit);
    }

    // Public typed-query compatibility surface. Prefix parsing stays here;
    // actual routing and normalization share the same resultsFor boundary.
    function results(text, limit) {
        var route = Dispatch.routePrefix(text, root.prefixes);
        return root.resultsFor(route.provider, route.query, route.prefix, limit);
    }
}
