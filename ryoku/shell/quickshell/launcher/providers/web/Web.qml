import QtQuick
import Quickshell
import "../../Singletons"
import "engines.js" as Engines
import ".."

// Web-search provider: the "?" prefix opens a search in the browser, with
// "!bang" shorthands (?!yt cats) picking a site. Also offered as a low-ranked
// fallback on a plain query so an unmatched search can still go to the web.
Provider {
    id: web

    providerId: "web"
    prefix: "?"

    // A query becomes a single "search the web" row. Scored low so it ranks below
    // real app matches in the default fan-out (the fallback pattern), and stands
    // alone under the "?" prefix.
    function query(text) {
        if (!text || text.length === 0)
            return [];
        return [{
            id: "web:" + text,
            title: text,
            subtitle: "Search " + Engines.engineName(text, "g"),
            icon: "",
            type: "Web",
            score: 90,
            actions: [{
                name: "Search",
                icon: "",
                execute: function () { Qt.openUrlExternally(Engines.buildUrl(text, "g")); }
            }]
        }];
    }

    Component.onCompleted: Dispatcher.register(web);
}
