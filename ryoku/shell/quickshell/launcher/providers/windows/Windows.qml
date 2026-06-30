import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../Singletons"
import "../../lib/fuzzy.js" as Fuzzy
import ".."

// Open-window switcher: lists Hyprland toplevels, fuzzy-matched by title and
// class, and focuses the picked one. A secondary action moves the window to the
// current workspace. Default-ranked just below apps so "fire" surfaces a running
// Firefox window under the app entry.
Provider {
    id: windows

    providerId: "windows"

    function normAddr(addr) {
        var a = String(addr || "");
        return a.indexOf("0x") === 0 ? a : "0x" + a;
    }

    function focusWindow(addr) {
        Hyprland.dispatch('hl.dsp.focus({ window = "address:' + normAddr(addr) + '" })');
    }

    function entries() {
        var out = [];
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            var o = t && t.lastIpcObject;
            if (!o || !o.address)
                continue;
            if (o.workspace && String(o.workspace.name).indexOf("special:") === 0)
                continue;
            out.push({
                address: o.address,
                title: o.title || o.class || "Window",
                cls: o.class || "",
                keywords: [o.class || ""]
            });
        }
        return out;
    }

    function rowFor(e) {
        return {
            id: "window:" + e.address,
            title: e.title,
            subtitle: e.cls,
            icon: e.cls ? Quickshell.iconPath(e.cls, "application-x-executable") : "",
            type: "Window",
            score: 5,
            actions: [{
                name: "Focus",
                icon: "",
                execute: function () { windows.focusWindow(e.address); }
            }]
        };
    }

    function query(text) {
        var list = windows.entries();
        var q = (text || "").trim().toLowerCase();
        var rows = [];
        for (var i = 0; i < list.length; i++)
            if (q.length === 0 || Fuzzy.score({ name: list[i].title, keywords: list[i].keywords }, q) < 99)
                rows.push(windows.rowFor(list[i]));
        return rows;
    }

    Component.onCompleted: Dispatcher.register(windows);
}
