import QtQuick
import Quickshell
import Quickshell.Io
import "../../Singletons"
import "../../lib/rofiscript.js" as RofiScript
import ".."

// Script provider: runs user scripts that speak the rofi-script protocol, so the
// existing ecosystem (rofimoji, rofi-rbw, custom menus) works in Ryoku unchanged.
// Scripts are declared in ~/.config/ryoku/launcher-scripts.json as
// [{ keyword, name, exec }]. Typing "<keyword> <query>" runs the script (pass 1,
// ROFI_RETV=0), parses its rows, and activating a row re-runs it (ROFI_RETV=1,
// ROFI_INFO=<row info>). Async + cached per keyword+query.
Provider {
    id: script

    providerId: "script"

    readonly property string configPath: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/launcher-scripts.json"
    property var scripts: []
    property string cachedKey: ""
    property var cachedRows: []
    property string pendingExec: ""
    property string pendingQuery: ""

    FileView {
        id: configFile
        path: script.configPath
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                var v = JSON.parse(configFile.text());
                script.scripts = Array.isArray(v) ? v : [];
            } catch (e) {
                script.scripts = [];
            }
        }
    }

    function matchScript(text) {
        for (var i = 0; i < script.scripts.length; i++) {
            var s = script.scripts[i];
            if (!s.keyword)
                continue;
            if (text === s.keyword || text.indexOf(s.keyword + " ") === 0)
                return { def: s, query: text.slice(s.keyword.length).replace(/^\s+/, "") };
        }
        return null;
    }

    function rowFor(def, row) {
        if (row.nonselectable)
            return null;
        return {
            id: "script:" + def.keyword + ":" + row.text,
            title: row.text,
            subtitle: def.name || def.keyword,
            icon: row.icon ? Quickshell.iconPath(row.icon, "") : "",
            type: def.name || "Script",
            score: 0,
            actions: [{
                name: "Select",
                icon: "",
                execute: function () {
                    activateProc.command = def.exec.concat([row.text]);
                    activateProc.environment = { ROFI_RETV: "1", ROFI_INFO: row.info };
                    activateProc.running = false;
                    activateProc.running = true;
                }
            }]
        };
    }

    function query(text) {
        var m = matchScript((text || "").trim());
        if (!m)
            return [];
        var key = m.def.keyword + "\u0000" + m.query;
        if (key === script.cachedKey) {
            var out = [];
            for (var i = 0; i < script.cachedRows.length; i++) {
                var r = script.rowFor(m.def, script.cachedRows[i]);
                if (r) out.push(r);
            }
            return out;
        }
        script.pendingExec = JSON.stringify(m.def.exec);
        script.pendingQuery = m.query;
        script.pendingKey = key;
        debounce.restart();
        return [];
    }

    property string pendingKey: ""

    Timer {
        id: debounce
        interval: 120
        repeat: false
        onTriggered: {
            listProc.command = JSON.parse(script.pendingExec);
            listProc.environment = { ROFI_RETV: "0", ROFI_INFO: script.pendingQuery };
            listProc.cacheKey = script.pendingKey;
            listProc.running = false;
            listProc.running = true;
        }
    }

    Process {
        id: listProc
        property string out: ""
        property string cacheKey: ""
        stdout: SplitParser {
            onRead: line => listProc.out += line + "\n"
        }
        onStarted: listProc.out = ""
        onExited: (code, status) => {
            // a killed (superseded) run must not cache truncated rows under
            // the newer query's key.
            if (status !== 0)
                return;
            script.cachedKey = listProc.cacheKey;
            script.cachedRows = RofiScript.parse(listProc.out).rows;
            Dispatcher.notifyAsync();
        }
    }

    Process {
        id: activateProc
    }

    Component.onCompleted: Dispatcher.register(script);
}
