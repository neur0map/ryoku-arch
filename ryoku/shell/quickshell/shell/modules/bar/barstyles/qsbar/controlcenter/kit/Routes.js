.pragma library

// The Control Center's CONFIGURE routes. Order is display order in the graph.
// Plugins and Health are intentionally omitted: Ryoku owns plugins through the
// shell plugin runtime + ryostore, and diagnostics through `ryoku doctor`.
var ROUTES = [
    { id: "bars",       label: "Bars",       desc: "Position, form, surface and accent.", icon: "view_agenda", keywords: "position top bottom form full fit dock notch surface border panel accent colour layout edit restore" },
    { id: "appearance", label: "Appearance", desc: "Per-widget content and surface.",     icon: "brush",       keywords: "widget icon fill colour visibility hide show compact density" },
    { id: "logo",       label: "Logo",       desc: "Launcher wordmark and mark.",          icon: "flag",        keywords: "launcher ryoku kanji wordmark brand mark" },
    { id: "workspaces", label: "Workspaces", desc: "Count and marker style.",              icon: "grid_view",   keywords: "workspace active five ten marker dots numbers glyph" },
    { id: "pickers",    label: "Pickers",    desc: "Media and image style.",               icon: "image",       keywords: "picker wallpaper theme screenshot video carousel hearthstone tanzaku" }
];

function byId(id) {
    for (var i = 0; i < ROUTES.length; i++)
        if (ROUTES[i].id === id) return ROUTES[i];
    return null;
}

function labelFor(id) {
    var r = byId(id);
    return r ? r.label : id;
}

function indexOf(id) {
    for (var i = 0; i < ROUTES.length; i++)
        if (ROUTES[i].id === id) return i;
    return -1;
}
