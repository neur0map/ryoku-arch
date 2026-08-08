pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Launch-frequency store shared with the legacy pill launcher's file, so usage
// history carries across the rework. A flat {id: count} map; bump on launch,
// read for the ranking tiebreak.
Singleton {
    id: root

    readonly property string file: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/launcher-usage.json"
    property var usage: ({})

    function get(id) {
        var c = id ? root.usage[id] : 0;
        return typeof c === "number" ? c : 0;
    }

    function bump(id) {
        if (!id)
            return;
        root.usage[id] = (root.usage[id] || 0) + 1;
        store.setText(JSON.stringify(root.usage));
        Dispatcher.notifyAsync();
    }

    FileView {
        id: store
        path: root.file
        blockLoading: true
        atomicWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        var raw = store.text();
        try {
            root.usage = raw && raw.length ? JSON.parse(raw) : ({});
        } catch (e) {
            root.usage = ({});
        }
        Dispatcher.notifyAsync();
    }
}
