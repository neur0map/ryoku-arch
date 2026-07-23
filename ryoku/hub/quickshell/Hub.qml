pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "schema/ShellSettingsPage.js" as ShellSchema
import "schema/AppearancePage.js" as AppearanceSchema
import "schema/WindowsPage.js" as WindowsSchema
import "schema/InputPage.js" as InputSchema
import "schema/KeybindsPage.js" as KeybindsSchema
import "schema/DisplaysPage.js" as DisplaysSchema
import "schema/GpuPage.js" as GpuSchema
import "schema/RecordingPage.js" as RecordingSchema
import "schema/DictationPage.js" as DictationSchema
import "schema/LauncherPage.js" as LauncherSchema
import "schema/FastfetchPage.js" as FastfetchSchema
import "schema/WidgetsPage.js" as WidgetsSchema
import "schema/LockscreenPage.js" as LockscreenSchema
import "schema/AnimationsPage.js" as AnimationsSchema
import "schema/AddonsPage.js" as AddonsSchema
import "schema/WindowRulesPage.js" as WindowRulesSchema
import "schema/AppOverridesPage.js" as AppOverridesSchema
import "schema/LayerRulesPage.js" as LayerRulesSchema
import "schema/AutostartPage.js" as AutostartSchema
import "schema/EnvironmentPage.js" as EnvironmentSchema
import "schema/PerformancePage.js" as PerformanceSchema
import "schema/UpdatesPage.js" as UpdatesSchema

// Ryoku Settings, assembled. The rail owns navigation and global search; the
// head, cells and tabs are drawn once by SchemaPage from a page's schema; the
// pinned side is the feedback loop (live preview, the dirty-state plate, the
// pending-write diff); the action bar is the one surface whose absence eats an
// edit, so it lives in the shell and no page can lose it.
//
// Nothing writes to disk except Save. Values live in `draft`; `committed` is
// what the JsonAdapters hold from disk; the diff is draft against committed,
// rendered in each file's own JSON syntax. Factory values live in `defs` and
// only RESET reaches for them.
Rectangle {
    id: hub

    implicitWidth: 1400
    implicitHeight: 880
    color: Tokens.paper
    focus: true

    // ── which page ───────────────────────────────────────────────────────
    property string section: "shell"
    // remember the last section so a reopen lands where you left, not on Shell.
    // Read once at startup by `sectionGet` below; written here on every change.
    onSectionChanged: Quickshell.execDetached(["ryoku-hub", "config", "set", "section", hub.section])
    property string query: ""

    // progressive disclosure: one global Advanced switch (in the rail) reveals the
    // deep knobs across every schema page. persisted like `section`, restored at
    // startup by `advancedGet` below.
    property bool advanced: false
    onAdvancedChanged: Quickshell.execDetached(["ryoku-hub", "config", "set", "advanced", hub.advanced ? "1" : "0"])

    // The full catalogue. `wired` marks the pages whose content and
    // persistence are ported; the rest render an honest porting plate rather
    // than a settings page that cannot save.
    readonly property var groups: [
        { name: "OVERVIEW", items: [ { key: "profile", name: "Profile" } ] },
        { name: "DEVICES", items: [
            { key: "displays", name: "Displays" }, { key: "connections", name: "Connections" },
            { key: "input", name: "Input" }, { key: "gpu", name: "GPU" } ] },
        { name: "DESKTOP", items: [
            { key: "windows", name: "Windows" }, { key: "appearance", name: "Appearance" }, { key: "shell", name: "Shell", wired: true },
            { key: "animations", name: "Animations" }, { key: "lockscreen", name: "Lockscreen" },
            { key: "launcher", name: "App Launcher" }, { key: "widgets", name: "Desktop Widgets" } ] },
        { name: "APPS & KEYS", items: [
            { key: "keybinds", name: "Keybinds" }, { key: "windowrules", name: "Window Rules" },
            { key: "appoverrides", name: "App Overrides" }, { key: "layerrules", name: "Layer Rules" } ] },
        { name: "TOOLS", items: [
            { key: "recording", name: "Recording" }, { key: "dictation", name: "Dictation" },
            { key: "fastfetch", name: "Fastfetch" } ] },
        { name: "SYSTEM", items: [
            { key: "performance", name: "Performance" }, { key: "autostart", name: "Autostart" },
            { key: "environment", name: "Environment" }, { key: "updates", name: "Updates" } ] },
        { name: "ADD-ONS", items: [
            { key: "store", name: "Store" }, { key: "addons", name: "Installed" },
            { key: "rashin", name: "Rashin" } ] },
        { name: "", items: [ { key: "credits", name: "Credits" } ] }
    ]

    // Each section's terse kanji, paired with its Latin name in the rail. Latin
    // names the thing; the kanji is its seal. The two scripts sitting together
    // is the texture, and every gloss is the real word, never decoration:
    // 外観 = appearance, 接続 = connections, 描画 = rendering (GPU), and so on.
    readonly property var jpName: ({
        "profile": "横顔", "displays": "画面", "input": "入力", "keybinds": "操作",
        "connections": "接続", "gpu": "描画", "recording": "録画", "dictation": "音声",
        "windows": "窓", "appearance": "外観", "shell": "外殻", "launcher": "起動", "fastfetch": "情報",
        "widgets": "部品", "lockscreen": "施錠", "animations": "動き", "store": "商店",
        "addons": "拡張", "windowrules": "規則", "appoverrides": "上書", "layerrules": "階層",
        "autostart": "自動", "environment": "環境", "performance": "性能", "rashin": "羅針",
        "updates": "更新", "credits": "謝辞"
    })

    // Extra search vocabulary per section: the words a user actually types that
    // the labels never use. This is what lets the search reach a page with no
    // schema rows (Connections, Store, Rashin) and cover synonyms the copy
    // avoids (transparency->opacity, startup->autostart, screensaver->lockscreen).
    readonly property var sectionKeywords: ({
        "profile": "dashboard status overview telemetry hostname cpu gpu memory uptime specs",
        "displays": "monitor screen resolution refresh scale rotation arrange mirror hidpi dual second external multiple",
        "connections": "wifi wi-fi wireless bluetooth network hotspot tether internet ethernet pair pairing device",
        "input": "keyboard mouse touchpad pointer trackpad sensitivity scroll layout dvorak remap capslock repeat gesture",
        "keybinds": "shortcuts hotkeys binds keys browser terminal editor files launch super",
        "gpu": "graphics nvidia amd vram passthrough vfio rendering hybrid performance",
        "recording": "screen record capture video screencast screenshot fps codec framerate",
        "dictation": "voice typing speech transcribe whisper microphone stt",
        "windows": "window windows rounding corners softness gaps border borders thickness colour tiling dwindle master scrolling layout opacity transparency transparent dim blur shadow glow glass wobble wobbly title bar titlebar float snap resize animation",
        "appearance": "cursor pointer theme palette accent color colour wallpaper background rice scheme dark light night bluelight comfort brightness backlight",
        "shell": "bar panel taskbar move reposition position notification osd toast frame font grain noise visualizer visualiser weather island sidebar brand logo mark surface",
        "launcher": "launcher spotlight command palette greeting weather home",
        "fastfetch": "fetch neofetch terminal system info logo ascii emblem readout",
        "widgets": "desktop widget clock calendar weather face overlay wallpaper",
        "lockscreen": "lock screensaver signin greeter skin theme login",
        "animations": "animation animations motion transition bezier curve speed feel wobbly disable enable toggle",
        "store": "store marketplace plugin widget install browse extras bundle addon download",
        "addons": "installed plugin addon extension manage enable remove update widget",
        "windowrules": "window rule float pin size place opacity class title override",
        "appoverrides": "app override per-app opacity blur corner class inherit opaque transparent",
        "layerrules": "layer rule namespace blur dim bar notification surface",
        "autostart": "autostart startup launch login run command boot",
        "environment": "environment variable env var session export",
        "performance": "performance battery power saving save lowpower potato lag cpu gpu ram memory idle freeze reduce motion fps",
        "rashin": "rashin agent ai assistant hermes vault memory skills chat code llm needle",
        "updates": "update upgrade version channel commit behind check origin",
        "credits": "credits thanks acknowledgement gratitude contributor"
    })

    // ── global search ────────────────────────────────────────────────────
    // The rail search matches page titles AND every option (label, hint, key)
    // inside every schema page, so "grain" finds the Shell grain slider from
    // anywhere. Ranking is fuzzy: exact word > substring > subsequence.
    readonly property var searchIndex: {
        var srcs = {
            "shell": ShellSchema.rows, "appearance": AppearanceSchema.rows, "windows": WindowsSchema.rows,
            "input": InputSchema.rows, "keybinds": KeybindsSchema.rows,
            "displays": DisplaysSchema.rows, "gpu": GpuSchema.rows,
            "recording": RecordingSchema.rows, "dictation": DictationSchema.rows,
            "launcher": LauncherSchema.rows, "fastfetch": FastfetchSchema.rows,
            "widgets": WidgetsSchema.rows, "lockscreen": LockscreenSchema.rows,
            "animations": AnimationsSchema.rows, "addons": AddonsSchema.rows,
            "windowrules": WindowRulesSchema.rows, "appoverrides": AppOverridesSchema.rows,
            "layerrules": LayerRulesSchema.rows, "autostart": AutostartSchema.rows,
            "environment": EnvironmentSchema.rows, "performance": PerformanceSchema.rows,
            "updates": UpdatesSchema.rows
        };
        // a real, navigable setting vs a doc-only "surface" row (an action button
        // or a dynamic-title note) whose engineering copy must never surface.
        var isSetting = function (r) {
            if (!r || !r.label) return false;
            if (r.ctl === "action" || r.ctl === "layoutdemo") return false;
            if (/^\s*\(/.test(r.label) || /\((action bar|quick action)\)/.test(r.label)) return false;
            return true;
        };
        // a result breadcrumb shows the group; the schemas hide engineering notes
        // in it (parentheticals, <dynamic> tokens), so drop those from display.
        var cleanGroup = function (g) {
            if (!g) return "";
            if (g.indexOf("(") >= 0 || g.indexOf("<") >= 0) return "";
            return g;
        };
        var nameOf = {}, out = [];
        for (var gi = 0; gi < groups.length; gi++)
            for (var ii = 0; ii < groups[gi].items.length; ii++) {
                var it = groups[gi].items[ii];
                nameOf[it.key] = it.name;
                out.push({ section: it.key, sectionName: it.name, group: "", tab: "", label: it.name, desc: "", kw: sectionKeywords[it.key] || "", key: "", isPage: true });
            }
        for (var k in srcs) {
            var rows = srcs[k] || [];
            for (var ri = 0; ri < rows.length; ri++) {
                var r = rows[ri];
                if (!isSetting(r)) continue;
                // a setting also matches its option values (h264, dwindle, dark,
                // fahrenheit): index the lowercase ones (skips DisplaysPage's
                // capitalised doc placeholders) so an enum value finds its row.
                var optkw = r.opts ? r.opts.filter(function (o) { return typeof o === "string" && /^[a-z0-9][a-z0-9 ._/-]*$/.test(o); }).join(" ") : "";
                out.push({ section: k, sectionName: nameOf[k] || k, group: cleanGroup(r.group), tab: r.tab || "", label: r.label, desc: r.desc || "", kw: optkw, key: r.key || "", isPage: false });
            }
        }
        return out;
    }
    function wordScore(w, text) {
        var tws = text.split(/[^a-z0-9]+/);
        var best = 0;
        for (var i = 0; i < tws.length; i++) {
            var tw = tws[i];
            if (tw === "") continue;
            var idx = tw.indexOf(w);
            if (idx === 0) { if (best < 1200) best = 1200; continue; }
            if (idx > 0) { var ss = 1000 - Math.min(idx, 50); if (ss > best) best = ss; continue; }
            if (w.length > tw.length) continue;
            var ti = 0, sc = 0, streak = 0, ok = true;
            for (var ci = 0; ci < w.length; ci++) {
                var f = tw.indexOf(w.charAt(ci), ti);
                if (f < 0) { ok = false; break; }
                streak = (f === ti) ? streak + 1 : 0;
                sc += 2 + streak * 3;
                ti = f + 1;
            }
            if (ok && sc > best) best = sc;
        }
        return best;
    }
    // Tolerant multi-word scoring: sum the words that DO match and scale by how
    // much of the query landed, rather than zeroing the moment one word misses.
    // A full-phrase match still wins (coverage 1.0), but "dark mode" or "second
    // monitor" surface their page on the word that hit instead of cliffing to
    // nothing -- the old AND-match made a single out-of-vocab word blank the rail.
    function searchScore(q, text) {
        var words = q.split(/\s+/), total = 0, matched = 0, n = 0;
        for (var wi = 0; wi < words.length; wi++) {
            if (!words[wi]) continue;
            n++;
            var s = wordScore(words[wi], text);
            if (s > 0) { total += s; matched++; }
        }
        if (matched === 0 || n === 0) return 0;
        return total * (matched / n);
    }
    readonly property var searchResults: {
        var q = query.toLowerCase().trim();
        if (q === "") return [];
        var scored = [];
        for (var i = 0; i < searchIndex.length; i++) {
            var e = searchIndex[i];
            // The full hay keeps a multi-word query matchable across fields; the
            // label is re-scored on top (specificity) and the section vocabulary
            // (its keywords) once more. A page that OWNS the queried word -- the
            // word is in that section's keyword set -- then floats above any
            // sub-setting that merely mentions it in a label, so "blur", "cursor"
            // and "battery" land the section, not a stray control that says it.
            var full = (e.label + " " + e.desc + " " + e.sectionName + " " + e.group + " " + e.tab + " " + e.kw).toLowerCase();
            var s = searchScore(q, full);
            if (s <= 0) continue;
            s += 2 * searchScore(q, e.label.toLowerCase());
            var kwHit = searchScore(q, (e.sectionName + " " + e.tab + " " + e.kw).toLowerCase());
            s += kwHit;
            if (e.isPage) s += 300 + 3 * kwHit;
            scored.push({ e: e, s: s });
        }
        scored.sort(function (a, b) { return b.s - a.s; });
        var out = [];
        for (var j = 0; j < Math.min(scored.length, 60); j++) out.push(scored[j].e);
        return out;
    }

    // Layout class per section, kept as sets so the chrome is derived from the
    // section and never from the mid-load item: that is what stops the rail,
    // side column and bar reflowing (flickering) during an async page swap.
    // `framed` pages keep the rail + bottom action bar; `ledger` pages also get
    // the right write-ledger column. Everything else is full-bleed.
    readonly property var framedSet: ({
        "shell": true, "appearance": true, "windows": true, "input": true, "animations": true,
        "windowrules": true, "appoverrides": true, "layerrules": true,
        "autostart": true, "environment": true
    })
    readonly property var ledgerSet: ({ "shell": true, "appearance": true, "windows": true })

    readonly property var pageMeta: ({
        "shell": { title: "Shell", eyebrow: "DESKTOP",
                   blurb: "The frame, the bar, notifications, and the desktop visualiser." }
    })
    function metaFor(s) {
        return hub.pageMeta[s] || { title: hub.nameFor(s), eyebrow: hub.groupFor(s), blurb: "" };
    }
    function nameFor(s) {
        for (var g = 0; g < groups.length; g++)
            for (var i = 0; i < groups[g].items.length; i++)
                if (groups[g].items[i].key === s) return groups[g].items[i].name;
        return s;
    }
    function groupFor(s) {
        for (var g = 0; g < groups.length; g++)
            for (var i = 0; i < groups[g].items.length; i++)
                if (groups[g].items[i].key === s) return groups[g].name || "SETTINGS";
        return "SETTINGS";
    }
    function isWired(s) {
        for (var g = 0; g < groups.length; g++)
            for (var i = 0; i < groups[g].items.length; i++)
                if (groups[g].items[i].key === s) return groups[g].items[i].wired === true;
        return false;
    }
    function pageFile(s) {
        var map = { "windows": "WindowsPage", "profile": "ProfilePage", "shell": "ShellPage", "environment": "EnvironmentPage", "autostart": "AutostartPage", "layerrules": "LayerRulesPage", "windowrules": "WindowRulesPage", "appoverrides": "AppOverridesPage", "animations": "AnimationsPage", "appearance": "AppearancePage", "input": "InputPage", "keybinds": "KeybindsPage", "dictation": "DictationPage", "displays": "DisplaysPage", "connections": "ConnectionsPage", "gpu": "GpuPage", "updates": "UpdatesPage", "rashin": "RashinPage", "recording": "RecordingPage", "performance": "PerformancePage", "launcher": "LauncherPage", "lockscreen": "LockscreenPage", "fastfetch": "FastfetchPage", "store": "StorePage", "addons": "AddonsPage", "widgets": "WidgetsPage", "credits": "CreditsPage" };
        return map[s] ? Qt.resolvedUrl("pages/" + map[s] + ".qml") : "";
    }
    function openPick(r) { picker.openFor(r); }

    // ── the store ─────────────────────────────────────────────────────────
    // draft is the live full map; committed mirrors disk; defs are factory.
    property var draft: ({})
    property var committed: ({})
    property bool pristine: true

    readonly property var defs: ({
        "frameRadius": 9, "roundness": 10, "frameBorder": 59, "frameEnabled": true,
        "frameSmoothing": 8, "frameOpacity": 1, "grainStrength": 0.09, "shadowStrength": 0.63, "shadowSize": 12,
        "surfaceColor": "#0f1115", "osdRadius": 28, "osdOpacity": 1,
        "barEnabled": true, "barPosition": "top", "barStyle": "noctalia", "barHeight": 30, "washiVariant": "ryoku", "atollVariant": "ilyamiro", "dyadVariant": "faithful",
        "barShowTitle": true, "barShowMedia": true, "barShowStatus": true,
        "barOccupiedWorkspaces": true, "islandEdge": "top", "islandAlong": -1,
        "islandHidden": false, "islandModules": ["workspaces", "clock", "date", "media"],
        "islandRadius": 17, "fontFamily": "JetBrainsMono Nerd Font", "fontScale": 1.3,
        "weatherLocation": "", "weatherUnit": "auto",
        "sidebarLeftEnabled": true, "sidebarRightEnabled": true, "sidebarLeftPanes": ["stash"],
        "sidebarRightPanes": ["notifications", "calendar", "media", "weather", "recording"],
        "sidebarClickless": true, "sidebarWidth": 340, "sidebarCornerSize": 34,
        "enabled": true, "bars": 64, "height": 0.42, "thickness": 0.58, "bloom": 0.6,
        "reflection": 0.1, "idleWave": true, "style": "bars", "shape": "rounded",
        "position": "bottom", "mirror": false, "segments": 10, "fps": 30,
        "adaptive": true, "smoothing": 0.5, "gain": 1.0, "peaks": false,
        "markText": "力", "markImage": "", "markTint": true, "name": "Ryoku",
        "language": "Auto"
    })

    // key -> source file, derived from the schema so it cannot drift.
    readonly property var srcOf: {
        var m = {};
        for (var i = 0; i < ShellSchema.rows.length; i++) {
            var r = ShellSchema.rows[i];
            if (r.src && r.src !== "none") m[r.key] = r.src;
        }
        return m;
    }
    function adapterFor(src) { return src === "viz" ? vizA : (src === "brand" ? brandA : shellA); }
    function fileFor(src) { return src === "viz" ? "visualizer" : (src === "brand" ? "brand" : "shell"); }

    function snapshot() {
        var s = {};
        for (var k in defs) { var src = srcOf[k] || "shell"; s[k] = adapterFor(src)[k]; }
        return s;
    }
    function rebase() {
        hub.committed = snapshot();
        if (hub.pristine) hub.draft = JSON.parse(JSON.stringify(hub.committed));
    }
    function val(k) { var v = draft[k]; return v === undefined ? committed[k] : v; }
    function edit(k, v) {
        hub.pristine = false;
        var d = {}; for (var x in draft) d[x] = draft[x];
        d[k] = v; hub.draft = d;
    }
    readonly property int dirty: {
        var n = 0;
        for (var k in defs) {
            if (draft[k] === undefined || committed[k] === undefined) continue;
            if (JSON.stringify(draft[k]) !== JSON.stringify(committed[k])) n++;
        }
        return n + hub.hyprChanges().length;
    }
    function save() {
        var files = {};
        for (var k in defs) {
            if (draft[k] === undefined || committed[k] === undefined) continue;
            if (JSON.stringify(draft[k]) === JSON.stringify(committed[k])) continue;
            var src = srcOf[k] || "shell";
            adapterFor(src)[k] = draft[k];
            files[src] = true;
        }
        if (files.shell) shellFV.writeAdapter();
        if (files.viz) vizFV.writeAdapter();
        if (files.brand) brandFV.writeAdapter();
        hub.committed = JSON.parse(JSON.stringify(hub.draft));
        // language rides the normal Save: the file it just wrote (shell.json) is
        // watched by every Ryoku surface's shared I18n, so the whole desktop
        // retranslates. Set it here too so this window switches deterministically.
        if (files.shell) I18n.configLang = hub.committed.language || "Auto";
        if (hub.hyprChanges().length) {
            hyprSave.command = ["ryoku-hub", "hypr", "save", JSON.stringify(hub.hyprDraft)];
            hyprSave.running = true;
            hub.hyprCommitted = JSON.parse(JSON.stringify(hub.hyprDraft));
        }
    }
    function revert() {
        hub.draft = JSON.parse(JSON.stringify(hub.committed));
        hub.hyprDraft = JSON.parse(JSON.stringify(hub.hyprCommitted));
        if (hub.hyprLoaded) { hyprRestore.command = ["ryoku-hub", "hypr", "restore"]; hyprRestore.running = true; }
    }
    function resetDefaults() {
        hub.pristine = false;
        hub.draft = JSON.parse(JSON.stringify(hub.defs));
        if (Object.keys(hub.hyprDefaults).length) hub.hyprDraft = JSON.parse(JSON.stringify(hub.hyprDefaults));
    }

    // the diff, grouped by file, in each file's own JSON syntax.
    readonly property var diff: {
        var by = { shell: [], viz: [], brand: [] };
        for (var k in defs) {
            if (draft[k] === undefined || committed[k] === undefined) continue;
            if (JSON.stringify(draft[k]) === JSON.stringify(committed[k])) continue;
            var src = srcOf[k] || "shell";
            by[src].push({ key: k, was: JSON.stringify(committed[k]), now: JSON.stringify(draft[k]) });
        }
        var out = [];
        var order = ["shell", "viz", "brand"];
        for (var i = 0; i < order.length; i++)
            if (by[order[i]].length)
                out.push({ file: hub.fileFor(order[i]) + ".json", changes: by[order[i]] });
        var hc = hub.hyprChanges();
        if (hc.length) out.push({ file: "settings.lua", changes: hc });
        return out;
    }

    Component.onCompleted: rebase()
    Process {
        id: sectionGet
        command: ["ryoku-hub", "config", "get", "section"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var s = this.text.trim();
                if (s && hub.pageFile(s) !== "") hub.section = s;
            }
        }
    }
    Process {
        id: advancedGet
        command: ["ryoku-hub", "config", "get", "advanced"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { if (this.text.trim() === "1") hub.advanced = true; }
        }
    }

    property string cfgDir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku"

    FileView {
        id: shellFV
        path: hub.cfgDir + "/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: hub.rebase()
        JsonAdapter {
            id: shellA
            property string language: "Auto"
            property real frameRadius: 9
            property real roundness: 10
            property real frameBorder: 59
            property bool frameEnabled: true
            property real frameSmoothing: 8
            property real frameOpacity: 1
            property real grainStrength: 0.09
            property real shadowStrength: 0.63
            property real shadowSize: 12
            property string surfaceColor: "#0f1115"
            property real osdRadius: 28
            property real osdOpacity: 1
            property bool barEnabled: true
            property string barPosition: "top"
            property string barStyle: "noctalia"
            property real barHeight: 30
            property bool barShowTitle: true
            property bool barShowMedia: true
            property bool barShowStatus: true
            property bool barOccupiedWorkspaces: true
            property bool barShowWeather: true
            property bool barShowSpecialWs: true
            property var barToggles: ["caffeine", "dnd", "nightlight"]
            property var barLayoutLeft: []
            property var barLayoutCentre: []
            property var barLayoutRight: []
            property string washiVariant: "ryoku"
            property string atollVariant: "ilyamiro"
            property string dyadVariant: "faithful"
            property string islandEdge: "top"
            property real islandAlong: -1
            property bool islandHidden: false
            property var islandModules: ["workspaces", "clock", "date", "media"]
            property real islandRadius: 17
            property string fontFamily: "JetBrainsMono Nerd Font"
            property real fontScale: 1.3
            property string weatherLocation: ""
            property string weatherUnit: "auto"
            property bool ryolayerEnabled: true
            property bool sidebarLeftEnabled: true
            property bool sidebarRightEnabled: true
            property var sidebarLeftPanes: ["stash"]
            property var sidebarRightPanes: ["notifications", "calendar", "media", "weather", "recording"]
            property bool sidebarClickless: true
            property real sidebarWidth: 340
            property real sidebarCornerSize: 34
        }
    }
    FileView {
        id: vizFV
        path: hub.cfgDir + "/visualizer.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: hub.rebase()
        JsonAdapter {
            id: vizA
            property bool enabled: true
            property real bars: 64
            property real height: 0.42
            property real thickness: 0.58
            property real bloom: 0.6
            property real reflection: 0.1
            property bool idleWave: true
            property string style: "bars"
            property string shape: "rounded"
            property string position: "bottom"
            property bool mirror: false
            property real segments: 10
            property real fps: 30
            property bool adaptive: true
            property real smoothing: 0.5
            property real gain: 1.0
            property bool peaks: false
        }
    }
    FileView {
        id: brandFV
        path: hub.cfgDir + "/brand.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: hub.rebase()
        JsonAdapter {
            id: brandA
            property string markText: "力"
            property string markImage: ""
            property bool markTint: true
            property string name: "Ryoku"
        }
    }

    // ── hypr backend (the Lua pages) ─────────────────────────────────────
    // Every Lua page persists through one nested object via ryoku-hub, not a
    // JsonAdapter. Pages read and write dotted paths (appearance.gapsIn); the
    // change shows up in the same dirty/diff/save the JSON pages use, grouped
    // under settings.lua. Nothing is written until Save calls `hypr save`.
    property var hyprCommitted: ({})
    property var hyprDraft: ({})
    property var hyprDefaults: ({})
    property bool hyprLoaded: false

    Process {
        id: hyprGet
        command: ["ryoku-hub", "hypr", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    hub.hyprCommitted = o;
                    if (hub.pristine || !hub.hyprLoaded) hub.hyprDraft = JSON.parse(JSON.stringify(o));
                    hub.hyprLoaded = true;
                } catch (e) { console.log("hub: hypr get parse failed: " + e); }
            }
        }
    }
    Process {
        id: hyprDefaultsGet
        command: ["ryoku-hub", "hypr", "defaults"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { hub.hyprDefaults = JSON.parse(this.text); } catch (e) {} }
        }
    }
    Process { id: hyprSave }

    // live preview: the shell owns it, not the pages. A hypr edit applies to the
    // running compositor (throttled) so "previewing live" is honest; revert and
    // an unsaved quit restore the compositor to what is on disk.
    property bool quitting: false
    onHyprDraftChanged: if (hub.hyprLoaded) hyprPreviewThrottle.restart()
    Timer {
        id: hyprPreviewThrottle
        interval: 140
        onTriggered: {
            hyprPreview.command = ["ryoku-hub", "hypr", "preview", JSON.stringify(hub.hyprDraft)];
            hyprPreview.running = true;
        }
    }
    Process { id: hyprPreview }
    Process { id: hyprRestore; onRunningChanged: if (!running && hub.quitting) Qt.quit() }
    function requestQuit() {
        if (hub.hyprLoaded && hub.hyprChanges().length) {
            hub.quitting = true;
            hyprRestore.command = ["ryoku-hub", "hypr", "restore"];
            hyprRestore.running = true;
        } else {
            Qt.quit();
        }
    }

    function hyprVal(path) { return hub.pathGet(hub.hyprDraft, path); }
    function hyprCommittedVal(path) { return hub.pathGet(hub.hyprCommitted, path); }
    function hyprEdit(path, v) {
        hub.pristine = false;
        var d = JSON.parse(JSON.stringify(hub.hyprDraft));
        hub.pathSet(d, path, v);
        hub.hyprDraft = d;
    }
    function pathGet(obj, path) {
        var parts = path.split("."), cur = obj;
        for (var i = 0; i < parts.length; i++) { if (cur === undefined || cur === null) return undefined; cur = cur[parts[i]]; }
        return cur;
    }
    function pathSet(obj, path, v) {
        var parts = path.split("."), cur = obj;
        for (var i = 0; i < parts.length - 1; i++) {
            if (typeof cur[parts[i]] !== "object" || cur[parts[i]] === null) cur[parts[i]] = {};
            cur = cur[parts[i]];
        }
        cur[parts[parts.length - 1]] = v;
    }
    function hyprChanges() {
        if (!hub.hyprLoaded) return [];
        var out = [];
        hub.walkHypr("", hub.hyprCommitted, hub.hyprDraft, out);
        return out;
    }
    function walkHypr(prefix, a, b, out) {
        var seen = {}, k;
        for (k in (b || {})) seen[k] = true;
        for (k in (a || {})) seen[k] = true;
        for (k in seen) {
            var pa = a ? a[k] : undefined, pb = b ? b[k] : undefined;
            var p = prefix ? prefix + "." + k : k;
            var oa = pa && typeof pa === "object" && !Array.isArray(pa);
            var ob = pb && typeof pb === "object" && !Array.isArray(pb);
            if (oa && ob) hub.walkHypr(p, pa, pb, out);
            // a key on only one side (added or removed) is a change too, not only
            // a modified value, so first-time sets of omitempty maps (apps,
            // keybindRebinds) mark the store dirty and light Save.
            else if (JSON.stringify(pa) !== JSON.stringify(pb)) out.push({ key: p, was: pa === undefined ? "(unset)" : JSON.stringify(pa), now: pb === undefined ? "(unset)" : JSON.stringify(pb) });
        }
    }

    Keys.onEscapePressed: hub.requestQuit()
    Keys.onPressed: (e) => {
        if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) {
            searchField.grabFocus();
            e.accepted = true;
        }
    }

    // the registration sheet: the HUD backdrop the whole instrument sits on.
    Reg { anchors.fill: parent }

    // ── rail ────────────────────────────────────────────────────────────
    Item {
        id: rail
        anchors { left: parent.left; top: parent.top; bottom: bar.top }
        width: Tokens.railW
        Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: Tokens.line }

        Column {
            id: railHead
            anchors { left: parent.left; right: parent.right; top: parent.top }
            anchors.margins: Tokens.s5
            spacing: Tokens.s4

            // the masthead as a poster plate: framed, register-ticked, with the
            // seal and a /// mark. The reference sheet's title block, scaled down.
            Rectangle {
                width: parent.width
                height: 64
                color: "transparent"
                radius: Tokens.radius
                border.width: Tokens.border
                border.color: Tokens.line
                Ticks { }
                Row {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s4 }
                    spacing: Tokens.s3
                    Text { text: "力"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: 22 }
                    Column {
                        spacing: 1
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: "RYOKU ARCH"; color: Tokens.ink; font.family: Tokens.ui
                            font.pixelSize: 14; font.weight: Font.Medium; font.letterSpacing: 2.4
                        }
                        Text {
                            text: "//SETTINGS_"; color: Tokens.inkMuted
                            font.family: Tokens.mono; font.pixelSize: 10; font.letterSpacing: 1.4
                        }
                    }
                }
                Text {
                    anchors { right: parent.right; top: parent.top; margins: Tokens.s2 }
                    text: "///"; color: Tokens.inkFaint
                    font.family: Tokens.mono; font.pixelSize: 10
                }
            }
            Field {
                id: searchField
                width: parent.width
                toolbar: true
                placeholder: I18n.tr("Search settings…")
                onEdited: (t) => hub.query = t
            }
            // progressive disclosure: one global switch reveals the deep knobs on
            // every schema page (SettingsSheet filters rows tagged `adv`). Kept in
            // the rail so it is one control, not one per page.
            Item {
                width: parent.width
                height: Tokens.ctlH
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: I18n.tr("Advanced settings")
                    color: hub.advanced ? Tokens.ink : Tokens.inkMuted
                    font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                    font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                }
                Sw {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    on: hub.advanced
                    onToggled: (v) => hub.advanced = v
                }
            }
        }

        // the rail foot: a genuine Code 39 plate, the poster's totem. It scans.
        Item {
            id: railFoot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            anchors.margins: Tokens.s5
            anchors.bottomMargin: Tokens.s4
            height: Tokens.s3 + edition.height + Tokens.s3 + plate.implicitHeight
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Tokens.lineSoft }
            // marginalia above the plate: an edition register, shared by every
            // page since the rail is the one always-present chrome.
            Marginalia {
                id: edition
                anchors { left: parent.left; top: parent.top; topMargin: Tokens.s3 }
                index: "BETA"; label: "18"
                glyph: "column"; glyph2: ""
                chevrons: false
            }
            Barcode {
                id: plate
                anchors { left: parent.left; bottom: parent.bottom }
                text: "RYOKU HUB"
                unit: 1.1
                barHeight: 14
            }
            Text {
                anchors { right: parent.right; bottom: parent.bottom; bottomMargin: 2 }
                text: "+"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: 10
            }
        }

        Flickable {
            id: navFlick
            anchors { left: parent.left; right: parent.right; top: railHead.bottom; bottom: railFoot.top }
            anchors.margins: Tokens.s5
            anchors.topMargin: Tokens.s4
            contentHeight: nav.height
            clip: true
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            // keep the active section on screen: jumping there by search, IPC or
            // a config-restored section must never leave the selection clipped at
            // the rail edge. Only scrolls when the item is actually off-screen,
            // and animates the scroll, so an in-view click never jumps the rail.
            function reveal(it) {
                var y = it.mapToItem(nav, 0, 0).y;
                if (y >= contentY && y + it.height <= contentY + height)
                    return;
                var max = Math.max(0, nav.height - height);
                railScroll.to = Math.max(0, Math.min(y - height / 2, max));
                railScroll.restart();
            }
            NumberAnimation {
                id: railScroll
                target: navFlick; property: "contentY"
                duration: Tokens.move; easing.type: Tokens.ease
            }

            Column {
                id: nav
                width: navFlick.width - 12
                spacing: 0

                Repeater {
                    model: hub.query === "" ? hub.groups : []
                    Column {
                        id: grp
                        required property var modelData
                        required property int index
                        width: nav.width
                        spacing: 0
                        // which group holds the open section: its header lifts up
                        // the ink ramp (faint -> dim) as a quiet "you are here",
                        // monochrome, never a colour, so the bone-plate item stays
                        // the one emphasis.
                        readonly property bool activeGroup: grp.modelData.items.some(function (i) { return i.key === hub.section; })

                        Item {
                            readonly property bool anyMatch: hub.query === ""
                                || grp.modelData.items.some(function (i) {
                                    return i.name.toLowerCase().indexOf(hub.query.toLowerCase()) >= 0;
                                })
                            width: parent.width
                            height: !anyMatch ? 0 : (grp.modelData.name === "" ? Tokens.s4 : 30)
                            visible: anyMatch
                            Row {
                                visible: grp.modelData.name !== ""
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.bottomMargin: 2
                                spacing: Tokens.s2
                                // the poster's plate numerals: each group carries
                                // its index, 01..05, in tabular mono.
                                Text {
                                    text: (grp.index + 1 < 10 ? "0" : "") + (grp.index + 1)
                                    color: grp.activeGroup ? Tokens.inkDim : Tokens.inkFaint
                                    font.family: Tokens.mono; font.pixelSize: 9
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: I18n.tr(grp.modelData.name); color: grp.activeGroup ? Tokens.inkDim : Tokens.inkFaint
                                    font.family: Tokens.ui; font.pixelSize: 9
                                    font.weight: Font.Medium; font.letterSpacing: 2
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: Math.max(0, nav.width - 130); height: 1; color: Tokens.lineSoft
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                                Rectangle {
                                    width: 1; height: 5; color: grp.activeGroup ? Tokens.lineStrong : Tokens.line
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.verticalCenterOffset: -2
                                }
                            }
                        }

                        Repeater {
                            model: grp.modelData.items
                            Item {
                                id: navItem
                                required property var modelData
                                readonly property bool match: hub.query === ""
                                    || modelData.name.toLowerCase().indexOf(hub.query.toLowerCase()) >= 0
                                width: nav.width
                                height: match ? 34 : 0
                                visible: match
                                readonly property bool sel: hub.section === modelData.key
                                onSelChanged: if (sel) navFlick.reveal(navItem)
                                Component.onCompleted: if (sel) navFlick.reveal(navItem)

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.topMargin: 1; anchors.bottomMargin: 1
                                    radius: Tokens.radius
                                    color: navItem.sel ? Tokens.bone : (nh.hovered ? Tokens.tint10 : "transparent")
                                    Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                }
                                // selection is typography, never a coloured bar:
                                // the live section takes the sheet's // lead. On
                                // the right, every item carries its kanji seal,
                                // Latin and Japanese sitting side by side.
                                Row {
                                    x: Tokens.s3
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: Tokens.s2
                                    Text {
                                        id: navLead
                                        visible: navItem.sel
                                        text: "//"
                                        color: Tokens.inkOnBoneDim
                                        font.family: Tokens.mono; font.pixelSize: 11
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        id: navLatin
                                        text: I18n.tr(navItem.modelData.name)
                                        color: navItem.sel ? Tokens.inkOnBone : Tokens.inkDim
                                        font.family: Tokens.ui; font.pixelSize: 14
                                        anchors.verticalCenter: parent.verticalCenter
                                        elide: Text.ElideRight
                                        width: Math.max(0, navKana.x - Tokens.s2 - Tokens.s3
                                            - (navItem.sel ? navLead.width + Tokens.s2 : 0))
                                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                    }
                                }
                                Text {
                                    id: navKana
                                    anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                                    text: hub.jpName[navItem.modelData.key] || ""
                                    color: navItem.sel ? Tokens.inkOnBoneDim : Tokens.inkFaint
                                    font.family: Tokens.jp; font.pixelSize: 12
                                    Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                }
                                HoverHandler { id: nh; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: { hub.query = ""; searchField.clear(); hub.section = navItem.modelData.key } }
                            }
                        }
                    }
                }
                // search results: when searching, the rail becomes a fuzzy-ranked
                // list of hits across every page's title and options. Clicking an
                // option jumps to its page and filters to it; a page hit just goes.
                Repeater {
                    model: hub.query !== "" ? hub.searchResults : []
                    Item {
                        id: resItem
                        required property var modelData
                        width: nav.width
                        height: 46
                        Rectangle {
                            anchors.fill: parent
                            anchors.topMargin: 1; anchors.bottomMargin: 1
                            radius: Tokens.radius
                            color: rh.hovered ? Tokens.tint10 : "transparent"
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            x: Tokens.s3
                            width: parent.width - Tokens.s3 * 2 - 24
                            spacing: 1
                            Text {
                                text: I18n.tr(resItem.modelData.label)
                                color: Tokens.inkDim
                                font.family: Tokens.ui; font.pixelSize: 13
                                width: parent.width; elide: Text.ElideRight
                            }
                            Text {
                                text: resItem.modelData.isPage
                                    ? "Page"
                                    : (resItem.modelData.sectionName + (resItem.modelData.group ? "  ›  " + resItem.modelData.group : ""))
                                color: Tokens.inkFaint
                                font.family: Tokens.mono; font.pixelSize: 9
                                width: parent.width; elide: Text.ElideRight
                            }
                        }
                        Text {
                            anchors { right: parent.right; rightMargin: Tokens.s3; verticalCenter: parent.verticalCenter }
                            text: hub.jpName[resItem.modelData.section] || ""
                            color: Tokens.inkFaint
                            font.family: Tokens.jp; font.pixelSize: 12
                        }
                        HoverHandler { id: rh; cursorShape: Qt.PointingHandCursor }
                        TapHandler {
                            onTapped: {
                                hub.section = resItem.modelData.section;
                                if (resItem.modelData.isPage) { hub.query = ""; searchField.clear(); }
                                else { hub.query = resItem.modelData.label; searchField.text = resItem.modelData.label; }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── the page ──────────────────────────────────────────────────────────
    Item {
        id: pageArea
        // full/framed and the ledger are derived from the section via the sets
        // above, never the loaded item, so the chrome holds still through an
        // async page swap (only the page content fades). A porting page (no
        // file) stays framed too.
        readonly property bool full: hub.pageFile(hub.section) !== "" && !hub.framedSet[hub.section]
        readonly property bool withSide: hub.ledgerSet[hub.section] === true
        anchors.left: rail.right
        anchors.top: parent.top
        anchors.bottom: pageArea.full ? parent.bottom : bar.top
        anchors.right: (pageArea.full || !pageArea.withSide) ? parent.right : side.left
        anchors.leftMargin: pageArea.full ? 0 : Tokens.s6
        anchors.rightMargin: pageArea.full ? 0 : (pageArea.withSide ? Tokens.s5 : Tokens.s6)
        anchors.topMargin: pageArea.full ? 0 : Tokens.s5
        anchors.bottomMargin: pageArea.full ? 0 : Tokens.s3

        // Two loaders crossfade the page: the incoming page loads async into the
        // hidden loader, then fades in as the visible one fades out, so the
        // content never blanks to bare paper mid-swap (that blank was the
        // "flicker on section change"). The new page always loads into the
        // non-front loader, so the visible page is never disturbed even on rapid
        // switches, and a stale load from a superseded switch never reveals.
        Item {
            id: pageHost
            anchors.fill: parent
            readonly property string src: hub.pageFile(hub.section)
            property Item front: lb
            onSrcChanged: pageHost.swap()
            Component.onCompleted: pageHost.swap()
            function swap() {
                var incoming = pageHost.front === la ? lb : la;
                if (incoming.source == pageHost.src && incoming.status === Loader.Ready)
                    pageHost.reveal(incoming);
                else
                    incoming.source = pageHost.src;
            }
            function reveal(l) {
                if (l.source != pageHost.src)
                    return;
                pageHost.front = l;
                la.opacity = la === l ? 1 : 0; la.z = la === l ? 1 : 0;
                lb.opacity = lb === l ? 1 : 0; lb.z = lb === l ? 1 : 0;
            }
            Loader {
                id: la
                anchors.fill: parent
                asynchronous: true
                opacity: 1
                // hidden once fully faded, so the parked page stops taking hover
                // (a stale tooltip was leaking through the overlay layer).
                visible: opacity > 0.01
                onLoaded: { if (item) item.hub = hub; pageHost.reveal(la); }
                Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
            }
            Loader {
                id: lb
                anchors.fill: parent
                asynchronous: true
                opacity: 0
                visible: opacity > 0.01
                onLoaded: { if (item) item.hub = hub; pageHost.reveal(lb); }
                Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
            }
        }

        // honest interim: a page whose content is not ported yet says so,
        // rather than showing settings it cannot persist.
        Column {
            visible: hub.pageFile(hub.section) === ""
            anchors.top: parent.top; anchors.left: parent.left
            spacing: Tokens.s2
            Row {
                spacing: Tokens.s2
                Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "力"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: I18n.tr(hub.groupFor(hub.section)); color: Tokens.inkMuted
                    font.family: Tokens.ui; font.pixelSize: 9; font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackMark; anchors.verticalCenter: parent.verticalCenter
                }
            }
            Text { text: I18n.tr(hub.nameFor(hub.section)); color: Tokens.ink; font.family: Tokens.display; font.pixelSize: Tokens.fTitle }
            Item { width: 1; height: Tokens.s4 }
            Text {
                text: "PORTING IN PROGRESS"; color: Tokens.inkDim; font.family: Tokens.ui
                font.pixelSize: 11; font.weight: Font.Medium; font.letterSpacing: 2
            }
            Text {
                width: 520
                text: "This page is being rebuilt into the monochrome instrument. Its settings and surfaces are wired page by page; the Shell page is the proven pattern."
                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: 13; wrapMode: Text.WordWrap
            }
        }
    }

    // ── side: the write ledger (state + pending diff) ───────────────────────
    // No live-preview mock: the edits already show live on the real desktop, so
    // a wireframe here was redundant clutter. This column is state and diff.
    Item {
        id: side
        visible: pageArea.withSide
        anchors { right: parent.right; top: parent.top; bottom: bar.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5; anchors.bottomMargin: Tokens.s3
        width: 360

        // state card: clean is a hairline; dirty inverts to bone.
        Rectangle {
            id: stateCard
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 72
            radius: Tokens.radius
            color: hub.dirty > 0 ? Tokens.bone : "transparent"
            border.width: Tokens.border
            border.color: hub.dirty > 0 ? Tokens.bone : Tokens.line
            Behavior on color { ColorAnimation { duration: Tokens.snap } }
            Ticks { color: hub.dirty > 0 ? Tokens.lineOnBone : Tokens.line }

            Row {
                anchors.fill: parent
                anchors.margins: Tokens.s4
                spacing: Tokens.s4
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: hub.dirty > 0
                    Text {
                        text: hub.dirty
                        color: Tokens.inkOnBone; font.family: Tokens.ui
                        font.pixelSize: 36; font.weight: Font.Light
                    }
                    Text {
                        text: "CHANGES"; color: Tokens.inkOnBoneDim; font.family: Tokens.ui
                        font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: 2
                    }
                }
                Rectangle { visible: hub.dirty > 0; width: 1; height: parent.height; color: Tokens.lineOnBone }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - (hub.dirty > 0 ? 150 : 0)
                    text: hub.dirty > 0 ? "Previewing live. Nothing is written until you save."
                                        : "Everything matches what is on disk."
                    color: hub.dirty > 0 ? Tokens.inkOnBoneDim : Tokens.inkMuted
                    font.family: Tokens.ui; font.pixelSize: 12; wrapMode: Text.WordWrap
                }
            }
        }

        // pending write: the diff, grouped by file, in file syntax.
        Item {
            anchors { left: parent.left; right: parent.right; top: stateCard.bottom; bottom: parent.bottom; topMargin: Tokens.s3 }

            Row {
                id: diffHead
                anchors { left: parent.left; right: parent.right; top: parent.top }
                Text {
                    text: "PENDING WRITE"; color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: 10; font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                }
                Item { width: parent.width - 200; height: 1 }
                Text {
                    text: "DIFF"; color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: 9
                }
            }

            // idle: the diff zone becomes a framed specimen, composed the way
            // the reference's image tiles are (art under a solid label bar, a
            // topic chip, a tategaki slat), never a floating photo. Type never
            // sits on the art: every label rides its own paper, so it reads.
            Rectangle {
                anchors { left: parent.left; right: parent.right; top: diffHead.bottom; bottom: parent.bottom; topMargin: Tokens.s3 }
                // crossfade with the diff list, never a hard cut: the at-rest
                // specimen fades as the first pending write lands.
                opacity: hub.diff.length === 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
                color: "transparent"
                radius: Tokens.radius
                border.width: Tokens.border
                border.color: Tokens.line
                clip: true

                Image {
                    anchors.fill: parent
                    anchors.margins: Tokens.border
                    source: Qt.resolvedUrl("art/dither-torii.png")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    opacity: 0.5
                }
                Ticks { }

                // topic chip, the reference's `001 // ABOUT` tag, on solid paper
                Rectangle {
                    anchors { left: parent.left; top: parent.top; margins: Tokens.s3 }
                    width: topic.implicitWidth + Tokens.s3 * 2
                    height: topic.implicitHeight + Tokens.s2
                    color: Tokens.paper
                    border.width: Tokens.border
                    border.color: Tokens.lineStrong
                    Row {
                        id: topic
                        anchors.centerIn: parent
                        spacing: Tokens.s2
                        Text { text: "空"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: "AT REST"; color: Tokens.inkMuted; font.family: Tokens.mono; font.pixelSize: 9; font.letterSpacing: 1.4; anchors.verticalCenter: parent.verticalCenter }
                    }
                }

                // the brand in vertical Japanese (tategaki), on its own slat
                Rectangle {
                    anchors { right: parent.right; top: parent.top; bottom: bottomBar.top; margins: Tokens.s3 }
                    width: 30
                    color: Tokens.paper
                    border.width: Tokens.border
                    border.color: Tokens.lineStrong
                    Column {
                        anchors.centerIn: parent
                        spacing: 1
                        Repeater {
                            model: ["リ", "ョ", "ク"]
                            Text {
                                required property string modelData
                                text: modelData; color: Tokens.ink
                                font.family: Tokens.jp; font.pixelSize: 15
                                anchors.horizontalCenter: parent.horizontalCenter
                            }
                        }
                    }
                }

                // the label bar: solid paper so the caption always reads
                Rectangle {
                    id: bottomBar
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: Tokens.border }
                    height: 42
                    color: Tokens.paper
                    Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top } height: 1; color: Tokens.line }
                    Column {
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: Tokens.s3 }
                        spacing: 1
                        Text {
                            text: "// NOTHING TO WRITE_"; color: Tokens.inkDim
                            font.family: Tokens.mono; font.pixelSize: 10; font.letterSpacing: 1.2
                        }
                        Text {
                            text: "edits queue here before they land on disk"; color: Tokens.inkFaint
                            font.family: Tokens.ui; font.pixelSize: 11
                        }
                    }
                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: Tokens.s3 }
                        text: "力"; color: Tokens.inkFaint; font.family: Tokens.jp; font.pixelSize: 14
                    }
                }
            }

            Flickable {
                anchors { left: parent.left; right: parent.right; top: diffHead.bottom; bottom: parent.bottom; topMargin: Tokens.s3 }
                contentHeight: diffCol.height
                clip: true
                opacity: hub.diff.length > 0 ? 1 : 0
                visible: opacity > 0.01
                Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }
                Column {
                    id: diffCol
                    width: parent.width - 14
                    spacing: Tokens.s3
                    Repeater {
                        model: hub.diff
                        Column {
                            id: fileGrp
                            required property var modelData
                            width: diffCol.width
                            spacing: Tokens.s1
                            Row {
                                spacing: Tokens.s2
                                Rectangle { width: 3; height: 3; radius: 0; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: fileGrp.modelData.file; color: Tokens.inkDim
                                    font.family: Tokens.mono; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
                                }
                                Text {
                                    text: "· " + fileGrp.modelData.changes.length; color: Tokens.inkFaint
                                    font.family: Tokens.mono; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Repeater {
                                model: fileGrp.modelData.changes
                                Column {
                                    required property var modelData
                                    width: fileGrp.width
                                    topPadding: 2
                                    Text {
                                        text: modelData.key + ":"; color: Tokens.inkDim
                                        font.family: Tokens.mono; font.pixelSize: 12
                                    }
                                    Row {
                                        spacing: Tokens.s2
                                        Text {
                                            text: modelData.was; color: Tokens.inkFaint; font.strikeout: true
                                            font.family: Tokens.mono; font.pixelSize: 12
                                        }
                                        Text { text: "→"; color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: 12 }
                                        Text {
                                            text: modelData.now; color: Tokens.ink
                                            font.family: Tokens.mono; font.pixelSize: 12
                                        }
                                    }
                                    Rectangle { width: parent.width; height: 1; color: Tokens.lineSoft }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── action bar ─────────────────────────────────────────────────────────
    ActionBar {
        id: bar
        visible: !pageArea.full
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
        dirty: hub.dirty
        onSaved: hub.save()
        onReverted: hub.revert()
        onReset: hub.resetDefaults()
    }

    // ── catalogue overlay (font pick) ──────────────────────────────────────
    Item {
        id: picker
        anchors.fill: parent
        visible: pickState.row !== null
        z: 900

        QtObject { id: pickState; property var row: null }

        function openFor(r) { pickState.row = r; pick.open(); }
        function close() { pickState.row = null; }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.55
            TapHandler { onTapped: picker.close() }
        }
        Picker {
            id: pick
            anchors.centerIn: parent
            title: pickState.row ? pickState.row.label : ""
            options: pickState.row ? (pickState.row.opts || []) : []
            current: pickState.row ? String(hub.val(pickState.row.key)) : ""
            onChose: (k) => { if (pickState.row) hub.edit(pickState.row.key, k); picker.close(); }
            onDismissed: picker.close()
        }
    }

    // this app's own grain, topmost. The shell's global overlay cuts a hole
    // where the Hub window sits, so this is the only grain it carries.
    Grain { anchors.fill: parent; z: 10000 }
}
