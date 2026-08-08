pragma Singleton
import QtQuick
import Quickshell

// Session view state for the switcher: which layout renders the entries and how
// they sort. Held in memory only, so it survives a reopen within a shell session
// but needs no shell.json key and no doctor reconciler (the "focused"
// customization surface). Mode and the type/colour filters are transient body
// state that resets each open; only the view shape and sort order persist here.
Singleton {
    id: root

    // "strips" (hero preview + shelf) | "hearthstone" (fanned cards) |
    // "drift" (two drifting belts) | "grid" (scan)
    property string layout: "strips"
    readonly property var layouts: ["strips", "hearthstone", "drift", "grid"]
    function cycleLayout() {
        var i = root.layouts.indexOf(root.layout);
        root.layout = root.layouts[(i + 1) % root.layouts.length];
    }
    function layoutLabel(id) {
        return id === "grid" ? "Grid"
            : id === "hearthstone" ? "Hearthstone"
            : id === "drift" ? "Drift" : "Strips";
    }

    // apply the focused wallpaper to the desktop while browsing (live canvas).
    // off = the strip is the preview and the pick applies only on keep.
    property bool livePreview: false

    // "colour" (hue buckets, the scan's own order) | "recent" (mtime) | "name"
    property string sort: "colour"
    readonly property var sorts: ["colour", "recent", "name"]
    function cycleSort() {
        var i = root.sorts.indexOf(root.sort);
        root.sort = root.sorts[(i + 1) % root.sorts.length];
    }
    function sortLabel(id) {
        return id === "colour" ? "Colour" : id === "recent" ? "Recent" : "Name";
    }
}
