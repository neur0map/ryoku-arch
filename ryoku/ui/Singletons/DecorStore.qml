pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Per-box decoration state, kept in ~/.config/ryoku/decor.json and watched, so a
// box you frame stays framed across a reopen. A box is keyed by a stable id
// (`Decor.boxId`) to an object: { shot, zoom, panX, panY }. Loads synchronously
// (`blockLoading`), so a `Decor` reads its saved state on the first frame rather
// than flashing the default. Written immediately on every edit -- this is a
// preference, not a Save-gated setting, so it never joins the Hub's dirty diff.
Singleton {
    id: store

    property var data: ({})

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/decor.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: { reload(); store._load(); }
        onLoadFailed: store.data = ({})
    }

    Component.onCompleted: store._load()

    function _load() {
        var t = file.text();
        if (!t) { store.data = ({}); return; }
        try { store.data = JSON.parse(t) || ({}); } catch (e) { store.data = ({}); }
    }

    // the saved object for a box, or an empty one; callers read fields defensively
    function box(id) {
        return (id && store.data && store.data[id]) ? store.data[id] : ({});
    }

    // merge a patch into a box and write through
    function put(id, patch) {
        if (!id)
            return;
        var d = store.data || ({});
        var b = d[id] || ({});
        for (var k in patch)
            b[k] = patch[k];
        d[id] = b;
        store.data = d;                        // notify bindings
        file.setText(JSON.stringify(d, null, 2));
    }
}
