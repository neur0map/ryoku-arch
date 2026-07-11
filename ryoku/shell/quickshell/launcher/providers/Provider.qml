import QtQuick

// Base contract every launcher provider implements. A provider answers a query
// with result rows; the dispatcher routes a prefixed query to the matching
// provider and fans an unprefixed one across the default set.
//
// query(text) returns an array of result objects:
//   { title, subtitle, icon, type, score, actions: [{ name, icon, execute }],
//     view? }
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
