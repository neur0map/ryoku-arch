import QtQuick

// Base contract every launcher provider implements. A provider answers a query
// with result rows; the dispatcher routes a prefixed query to the matching
// provider and fans an unprefixed one across the default set.
//
// query(text, prefix) returns provider-local result objects:
//   { id, title, subtitle, icon, type, score,
//     actions: [{ id, name, icon, execute, enabled?, closeOnExecute? }], view? }
// The dispatcher attaches providerId and the collision-safe resultKey, validates
// raw action slot zero as the primary, then exposes primaryAction,
// secondaryActions, and disabled. Result IDs stay stable for the underlying
// entry; action IDs stay stable within that result and never derive from a
// display label. A malformed or disabled primary leaves the row informational
// and never promotes a later action.
// Lower score ranks higher. `prefix` is one char ("=", ">", "/", ...) or "".
// `defaultProvider` includes the provider in the unprefixed fan-out.
// An Item (not a QtObject) so a provider can hold child objects (Timer, Process,
// FileView) for its async work; it has no size and never renders.
Item {
    id: provider

    property string providerId: ""
    property string prefix: ""
    // optional extra prefixes that all route here; query()'s 2nd arg is the
    // matched prefix, so one provider can serve several modes (find: /file ...).
    property var prefixes: []
    property bool defaultProvider: true
    // when true and not a default provider, the dispatcher still includes this
    // provider in the fan-out for a numeric-looking query (e.g. the calculator).
    property bool numericFallback: false

    // Override in a concrete provider. Default is no results.
    function query(text) {
        return [];
    }
}
