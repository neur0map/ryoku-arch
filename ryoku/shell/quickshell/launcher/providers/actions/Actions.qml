import QtQuick
import Quickshell
import "../../Singletons"
import "../../lib/fuzzy.js" as Fuzzy
import "catalog.js" as Catalog
import ".."

// System-action provider: the "/" prefix lists fire-and-forget commands (lock,
// wallpaper, screenshot, night light, media keys, settings...) from the catalog,
// fuzzy-filtered. Each action runs its catalog `exec` argv detached. The active
// category tab (set by the view) narrows the list.
Provider {
    id: actions

    providerId: "actions"
    prefix: "/"
    defaultProvider: false

    property string activeCategory: "All"

    function rowFor(entry) {
        return {
            id: "action:" + entry.id,
            title: entry.name,
            subtitle: entry.category,
            icon: "",
            type: entry.category,
            score: 0,
            category: entry.category,
            actions: [{
                name: "Run",
                icon: "",
                execute: function () { Quickshell.execDetached(entry.exec); }
            }]
        };
    }

    function query(text) {
        var pool = Catalog.CATALOG.filter(function (a) {
            return actions.activeCategory === "All" || a.category === actions.activeCategory;
        });
        var q = (text || "").trim().toLowerCase();
        var rows = [];
        for (var i = 0; i < pool.length; i++) {
            if (q.length === 0 || Fuzzy.score({ name: pool[i].name, keywords: [pool[i].category] }, q) < 99)
                rows.push(rowFor(pool[i]));
        }
        return rows;
    }

    Component.onCompleted: Dispatcher.register(actions);
}
