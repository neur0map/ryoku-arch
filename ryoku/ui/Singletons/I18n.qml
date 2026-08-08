pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The one translation lookup, shared by every Ryoku surface (Hub, shell, apps).
// Source-string-as-key: `I18n.tr("Power limit")` returns the current language's
// string, or the English key itself when there is no translation, so the UI is
// never broken and translating is purely additive. English is the source of
// truth in code; the per-language files are generated (see ryoku/ui/i18n-sync.py),
// so a developer only ever writes English.
//
// The language is a global shell setting (shell.json "language"), set from the
// Hub's Shell page and watched here, so changing it retranslates every open
// surface live -- no relogin. Translations ship inside this module
// (../translations/<lang>.json), resolved relative to this file, so dev
// (~/.local/lib) and installed (/usr/lib) both work. Brand kana (力, 描画, seals)
// are never wrapped, so they stay put.
Singleton {
    id: i18n

    // shell.json stores the human-readable choice; map it to a file code.
    readonly property var names: ({
            "Auto": "auto",
            "English": "en",
            "Español": "es",
            "Français": "fr",
            "Português": "pt",
            "Português (BR)": "pt_BR"
        })

    property string configLang: "auto"     // raw value from shell.json (name or code)
    readonly property string lang: {
        var sel = i18n.names[i18n.configLang] || i18n.configLang;   // name -> code, else raw
        if (sel && sel !== "auto")
            return sel;
        var n = Qt.locale().name;           // es_ES, pt_BR, pt_PT, fr_FR, en_US, ...
        if (n === "pt_BR")
            return "pt_BR";
        return n.split("_")[0];             // es, pt, fr, en, ...
    }
    property var map: ({})       // shipped translations
    property var genMap: ({})    // user/AI-generated, layered on top (Noctalia-style)

    // absolute path to a shipped language file, resolved next to this singleton.
    function _trPath(l) {
        return ("" + Qt.resolvedUrl("../translations/" + l + ".json")).replace(/^file:\/\//, "");
    }
    // user/AI-generated translations live in the config dir, so a language the
    // shell did not ship (or a better LLM pass) can be dropped in and layered.
    function _genPath(l) {
        return (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/i18n/" + l + ".json";
    }

    // the global config; language lives under "language", watched for live switch.
    FileView {
        id: cfg
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: true
        atomicWrites: true
        printErrors: false
        onFileChanged: { reload(); i18n._loadCfg(); }
        onLoadFailed: i18n.configLang = "auto"
    }

    // the active language's string map; path rebinds when `lang` changes.
    FileView {
        id: tf
        path: i18n._trPath(i18n.lang)
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: i18n._loadMap()
        onFileChanged: { reload(); i18n._loadMap(); }
        onLoadFailed: i18n.map = ({})      // no file (e.g. English) -> keys are the strings
    }

    // the user/AI-generated overlay for the active language; empty when absent.
    FileView {
        id: gen
        path: i18n._genPath(i18n.lang)
        blockLoading: true
        watchChanges: true
        printErrors: false
        onLoaded: i18n._loadGen()
        onFileChanged: { reload(); i18n._loadGen(); }
        onLoadFailed: i18n.genMap = ({})
    }

    Component.onCompleted: i18n._loadCfg()

    function _loadCfg() {
        try {
            i18n.configLang = (JSON.parse(cfg.text()) || {}).language || "auto";
        } catch (e) {
            i18n.configLang = "auto";
        }
    }
    function _loadMap() {
        try {
            var t = tf.text();
            i18n.map = t ? (JSON.parse(t) || {}) : ({});
        } catch (e) {
            i18n.map = ({});
        }
    }
    function _loadGen() {
        try {
            var t = gen.text();
            i18n.genMap = t ? (JSON.parse(t) || {}) : ({});
        } catch (e) {
            i18n.genMap = ({});
        }
    }

    // the lookup. English key in, translated (or the key) out. A user/AI-generated
    // string wins over the shipped one, which wins over the English key.
    function tr(s) {
        if (s === undefined || s === null || s === "")
            return s;
        var k = "" + s;
        var g = i18n.genMap[k];
        if (g !== undefined && g !== "")
            return g;
        var v = i18n.map[k];
        return v === undefined ? s : v;
    }
}
