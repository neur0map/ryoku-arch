pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// RyoLayer state: blur strength and the widget instances (per screen: where,
// how big, pinned). ~/.config/ryoku/ryolayer.json, watched and atomic, the
// same contract as launcher.json / widgets.json. Geometry is a normalized
// center + pixel size so a resolution change or monitor swap keeps layouts.
Singleton {
    id: root

    property alias bgBlur: adapter.bgBlur
    readonly property var widgets: adapter.widgets

    // bumps on every widget mutation; bindings that call entry() depend on it.
    property int rev: 0

    FileView {
        id: file
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/ryolayer.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: { reload(); root.rev++; }

        JsonAdapter {
            id: adapter
            property int bgBlur: 24
            property var widgets: []
        }
    }

    function save() {
        file.writeAdapter();
        root.rev++;
    }

    function entry(id, screen) {
        var w = adapter.widgets || [];
        for (var i = 0; i < w.length; i++)
            if (w[i].id === id && w[i].screen === screen)
                return w[i];
        return null;
    }

    function place(id, screen) {
        if (entry(id, screen))
            return;
        var def = Catalog.byId(id);
        if (!def)
            return;
        var w = (adapter.widgets || []).slice();
        w.push({ id: id, screen: screen, cx: 0.5, cy: 0.45,
                 w: def.defW, h: def.defH, pinned: false, clickthrough: false });
        adapter.widgets = w;
        save();
    }

    function remove(id, screen) {
        var w = (adapter.widgets || []).filter(function (e) {
            return !(e.id === id && e.screen === screen);
        });
        adapter.widgets = w;
        save();
    }

    function patch(id, screen, fields) {
        var w = (adapter.widgets || []).slice();
        for (var i = 0; i < w.length; i++) {
            if (w[i].id !== id || w[i].screen !== screen)
                continue;
            var e = JSON.parse(JSON.stringify(w[i]));
            for (var k in fields)
                e[k] = fields[k];
            w[i] = e;
            adapter.widgets = w;
            save();
            return;
        }
    }

    function setGeometry(id, screen, cx, cy, wpx, hpx) { patch(id, screen, { cx: cx, cy: cy, w: wpx, h: hpx }); }
    function setPinned(id, screen, on)                 { patch(id, screen, { pinned: on }); }
    function setClickthrough(id, screen, on)           { patch(id, screen, { clickthrough: on }); }

    // seed only on a genuine first run, never over a present file.
    Component.onCompleted: if (!file.text()) file.writeAdapter();
}
