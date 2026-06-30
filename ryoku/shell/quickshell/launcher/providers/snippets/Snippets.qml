import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import "../../lib/fuzzy.js" as Fuzzy
import "placeholders.js" as Placeholders
import ".."

// Snippets + quicklinks provider. Snippets expand dynamic placeholders ({date},
// {clipboard}, {selection}, {cursor}) and copy to the clipboard; quicklinks open
// a URL with {query} substituted. Both are read from JSON under ~/.config/ryoku,
// fuzzy-matched by keyword/name. Default-ranked below apps.
Provider {
    id: snippets

    providerId: "snippets"

    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku"
    property var snippetList: []
    property var quicklinkList: []

    FileView {
        id: snippetFile
        path: snippets.dir + "/launcher-snippets.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: snippets.snippetList = snippets.parseList(snippetFile.text())
    }
    FileView {
        id: quicklinkFile
        path: snippets.dir + "/launcher-quicklinks.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: snippets.quicklinkList = snippets.parseList(quicklinkFile.text())
    }

    function parseList(raw) {
        try {
            var v = raw && raw.length ? JSON.parse(raw) : [];
            return Array.isArray(v) ? v : [];
        } catch (e) {
            return [];
        }
    }

    function context() {
        return { now: new Date(), clipboard: Quickshell.clipboardText, selection: "" };
    }

    function snippetRow(entry) {
        return {
            id: "snippet:" + (entry.name || entry.keyword || entry.body),
            title: entry.name || entry.keyword || "Snippet",
            subtitle: "Snippet",
            icon: "",
            type: "Snippet",
            score: 40,
            actions: [{
                name: "Copy",
                icon: "",
                execute: function () {
                    Quickshell.clipboardText = Placeholders.expand(entry.body || "", snippets.context()).text;
                }
            }]
        };
    }

    function quicklinkRow(entry, text) {
        return {
            id: "quicklink:" + (entry.name || entry.url),
            title: entry.name || entry.url,
            subtitle: "Quicklink",
            icon: "",
            type: "Quicklink",
            score: 40,
            actions: [{
                name: "Open",
                icon: "",
                execute: function () {
                    var url = String(entry.url || "").replace(/\{query\}/g, encodeURIComponent(text));
                    Qt.openUrlExternally(url);
                }
            }]
        };
    }

    function matchable(entry) {
        return { name: entry.name || entry.keyword || "", keywords: entry.keywords || [] };
    }

    function query(text) {
        if (!text || text.length === 0)
            return [];
        var rows = [];
        var q = text.toLowerCase();
        for (var i = 0; i < snippets.snippetList.length; i++)
            if (Fuzzy.score(snippets.matchable(snippets.snippetList[i]), q) < 99)
                rows.push(snippets.snippetRow(snippets.snippetList[i]));
        for (var j = 0; j < snippets.quicklinkList.length; j++)
            if (Fuzzy.score(snippets.matchable(snippets.quicklinkList[j]), text.toLowerCase()) < 99)
                rows.push(snippets.quicklinkRow(snippets.quicklinkList[j], text));
        return rows;
    }

    Component.onCompleted: Dispatcher.register(snippets);
}
