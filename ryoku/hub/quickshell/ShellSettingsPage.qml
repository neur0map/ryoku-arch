pragma ComponentBehavior: Bound
import QtQuick
import "schema/ShellSettingsPage.js" as Schema
import QtQuick.Controls
import QtQuick.Dialogs
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import "Singletons"

// Shell Settings: live editor for the Ryoku shell's look. every edit hits the
// running shell at once via ~/.config/ryoku/shell.json (throttled, atomic),
// which the shell watches. preview = your actual desktop (the frame around
// this window, the bar riding it). Save keeps it; Revert and leaving the
// section put the saved look back. controls match the value: steppers for
// exact pixels, sliders for opacity/feel, swatch for colour.
Item {
    id: page

    readonly property var shellKeys: [
        "frameRadius", "roundness", "frameBorder", "frameEnabled", "frameSmoothing", "frameOpacity",
        "shadowStrength", "shadowSize", "surfaceColor",
        "osdRadius", "osdOpacity",
        "barEnabled", "barPosition", "barStyle", "barHeight",
        "barShowTitle", "barShowMedia", "barShowStatus", "barOccupiedWorkspaces",
        "islandEdge", "islandAlong", "islandHidden", "islandModules", "islandRadius",
        "fontFamily", "fontScale",
        "weatherLocation", "weatherUnit",
        "sidebarLeftEnabled", "sidebarRightEnabled", "sidebarLeftPanes", "sidebarRightPanes",
        "sidebarClickless", "sidebarWidth", "sidebarCornerSize"
    ]
    readonly property var vizKeys: [
        "enabled", "bars", "height", "thickness", "bloom", "reflection", "idleWave",
        "style", "shape", "position", "mirror", "segments",
        "fps", "adaptive", "smoothing", "gain", "peaks"
    ]
    // brand identity (~/.config/ryoku/brand.json), edited in the Global tab and
    // shared with doctor: the desktop mark + name. Ryoku's own apps
    // keep their brand and ignore these.
    readonly property var brandKeys: ["markText", "markImage", "markTint", "name"]
    readonly property var keys: page.shellKeys.concat(page.vizKeys).concat(page.brandKeys)

    // fonts offered in the Global tab: the popular set people rice with, keyed by
    // the family name fontconfig reports. only the ones actually installed
    // (fontScan below) show, and the list grows as you add your own. curated on
    // purpose, not every family on the system.
    readonly property var fontCatalog: [
        { "key": "JetBrainsMono Nerd Font", "label": "JetBrains Mono", "hint": "nerd" },
        { "key": "FiraCode Nerd Font", "label": "Fira Code", "hint": "nerd" },
        { "key": "Hack Nerd Font", "label": "Hack", "hint": "nerd" },
        { "key": "CaskaydiaCove Nerd Font", "label": "Cascadia Code", "hint": "nerd" },
        { "key": "Iosevka Nerd Font", "label": "Iosevka", "hint": "nerd" },
        { "key": "MesloLGS Nerd Font", "label": "Meslo", "hint": "nerd" },
        { "key": "SauceCodePro Nerd Font", "label": "Source Code Pro", "hint": "nerd" },
        { "key": "UbuntuMono Nerd Font", "label": "Ubuntu Mono", "hint": "nerd" },
        { "key": "RobotoMono Nerd Font", "label": "Roboto Mono", "hint": "nerd" },
        { "key": "BlexMono Nerd Font", "label": "IBM Plex Mono", "hint": "nerd" },
        { "key": "GeistMono Nerd Font", "label": "Geist Mono", "hint": "nerd" },
        { "key": "CommitMono Nerd Font", "label": "Commit Mono", "hint": "nerd" },
        { "key": "Terminess Nerd Font", "label": "Terminus", "hint": "nerd" },
        { "key": "DejaVuSansMono Nerd Font", "label": "DejaVu Sans Mono", "hint": "nerd" },
        { "key": "Maple Mono NF", "label": "Maple Mono", "hint": "nerd" },
        { "key": "Inter", "label": "Inter", "hint": "sans" },
        { "key": "Roboto", "label": "Roboto", "hint": "sans" },
        { "key": "Ubuntu", "label": "Ubuntu", "hint": "sans" },
        { "key": "Cantarell", "label": "Cantarell", "hint": "sans" },
        { "key": "Lexend", "label": "Lexend", "hint": "sans" },
        { "key": "Fira Sans", "label": "Fira Sans", "hint": "sans" },
        { "key": "Noto Sans", "label": "Noto Sans", "hint": "sans" },
        { "key": "Noto Sans CJK JP", "label": "Noto Sans JP", "hint": "cjk" },
        { "key": "Space Grotesk", "label": "Space Grotesk", "hint": "display" },
        { "key": "Fraunces", "label": "Fraunces", "hint": "display" }
    ]
    // families fontconfig reports as installed. seeded with what Ryoku ships so
    // the picker is sane before the scan returns; fontScan replaces it.
    property var installedFonts: ["JetBrainsMono Nerd Font", "Inter", "Noto Sans", "Noto Sans CJK JP", "Fraunces", "Space Grotesk"]
    // the catalog filtered to installed, with the current selection always kept
    // (a hand-set custom family still shows and stays selected).
    readonly property var fontOptions: {
        var out = [];
        var curInCatalog = false;
        for (var i = 0; i < page.fontCatalog.length; i++) {
            var f = page.fontCatalog[i];
            if (f.key === draft.fontFamily) { curInCatalog = true; out.push(f); continue; }
            if (page.installedFonts.indexOf(f.key) >= 0) out.push(f);
        }
        if (!curInCatalog && draft.fontFamily && draft.fontFamily.length > 0)
            out.unshift({ "key": draft.fontFamily, "label": draft.fontFamily, "hint": "custom" });
        return out;
    }

    // mirror of the shells' canonical defaults (pill Singletons/Config.qml +
    // visualizer Singletons/Config.qml). only used for "Reset to defaults".
    readonly property var defaults: ({
        "frameRadius": 9, "roundness": 10, "frameBorder": 59, "frameEnabled": true, "frameSmoothing": 8, "frameOpacity": 1,
        "shadowStrength": 0.63, "shadowSize": 12, "surfaceColor": "#0f1115",
        "osdRadius": 28, "osdOpacity": 1,
        "barEnabled": true, "barPosition": "top", "barStyle": "noctalia", "barHeight": 30,
        "barShowTitle": true, "barShowMedia": true, "barShowStatus": true, "barOccupiedWorkspaces": true,
        "islandEdge": "top", "islandAlong": -1, "islandHidden": false, "islandModules": ["workspaces", "clock", "date", "media"], "islandRadius": 17,
        "fontFamily": "JetBrainsMono Nerd Font", "fontScale": 1.3,
        "weatherLocation": "", "weatherUnit": "auto",
        "sidebarLeftEnabled": true, "sidebarRightEnabled": true, "sidebarLeftPanes": ["stash"], "sidebarRightPanes": ["notifications", "calendar", "media", "weather", "recording"],
        "sidebarClickless": true, "sidebarWidth": 340, "sidebarCornerSize": 34,
        "enabled": true, "bars": 64, "height": 0.42, "thickness": 0.58,
        "bloom": 0.6, "reflection": 0.1, "idleWave": true,
        "style": "bars", "shape": "rounded", "position": "bottom", "mirror": false,
        "segments": 10, "fps": 30, "adaptive": true, "smoothing": 0.5, "gain": 1.0, "peaks": false,
        "markText": "\u529b", "markImage": "", "markTint": true, "name": "Ryoku"
    })

    property string group: "frame"
    property bool shellLoaded: false
    property bool vizLoaded: false
    property bool brandLoaded: false
    readonly property bool ready: page.shellLoaded && page.vizLoaded && page.brandLoaded
    // last saved look. compare against it for dirty state; Revert and
    // leave-without-save restore from this.
    property var committedVals: ({})

    QtObject {
        id: draft
        property real frameRadius: 9
        property real roundness: 10
        property real frameBorder: 59
        property bool frameEnabled: true
        property real frameSmoothing: 8
        property real frameOpacity: 1
        property real shadowStrength: 0.63
        property real shadowSize: 12
        property color surfaceColor: "#0f1115"
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
        property string islandEdge: "top"
        property real islandAlong: -1
        property bool islandHidden: false
        property var islandModules: ["workspaces", "clock", "date", "media"]
        property real islandRadius: 17
        property string fontFamily: "JetBrainsMono Nerd Font"
        property real fontScale: 1.3
        property string weatherLocation: ""
        property string weatherUnit: "auto"
        property bool sidebarLeftEnabled: true
        property bool sidebarRightEnabled: true
        property var sidebarLeftPanes: ["stash"]
        property var sidebarRightPanes: ["notifications", "calendar", "media", "weather", "recording"]
        property bool sidebarClickless: true
        property real sidebarWidth: 340
        property real sidebarCornerSize: 34
        property bool enabled: true
        property int bars: 64
        property real height: 0.42
        property real thickness: 0.58
        property real bloom: 0.6
        property real reflection: 0.1
        property bool idleWave: true
        property string style: "bars"
        property string shape: "rounded"
        property string position: "bottom"
        property bool mirror: false
        property int segments: 10
        property int fps: 30
        property bool adaptive: true
        property real smoothing: 0.5
        property real gain: 1.0
        property bool peaks: false
        property string markText: "\u529b"
        property string markImage: ""
        property bool markTint: true
        property string name: "Ryoku"
    }

    function sameVal(a, b) { return String(a) === String(b); }

    readonly property bool dirty: {
        if (!page.ready)
            return false;
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            if (!page.sameVal(draft[k], page.committedVals[k]))
                return true;
        }
        return false;
    }

    // pull a file's keys into draft + the committed baseline (fresh object
    // each time so bindings on the baseline re-evaluate).
    function adopt(keyset, adptr) {
        var c = {};
        for (var k in page.committedVals)
            c[k] = page.committedVals[k];
        for (var i = 0; i < keyset.length; i++) {
            var kk = keyset[i];
            draft[kk] = adptr[kk];
            c[kk] = adptr[kk];
        }
        page.committedVals = c;
    }

    // a later external write (the shell deck flipping the visualizer on/off)
    // reloaded into the adapter. pull it into any key the user hasn't locally
    // edited and move that key's baseline forward, leaving edited keys' drafts
    // and baselines untouched.
    function adoptExternal(keyset, adptr) {
        var c = {};
        for (var k in page.committedVals)
            c[k] = page.committedVals[k];
        for (var i = 0; i < keyset.length; i++) {
            var kk = keyset[i];
            if (page.sameVal(draft[kk], page.committedVals[kk])) {
                draft[kk] = adptr[kk];
                c[kk] = adptr[kk];
            }
        }
        page.committedVals = c;
    }

    function flush() {
        var i, k;
        for (i = 0; i < page.shellKeys.length; i++) { k = page.shellKeys[i]; shellA[k] = draft[k]; }
        cfgShell.writeAdapter();
        for (i = 0; i < page.vizKeys.length; i++) { k = page.vizKeys[i]; vizA[k] = draft[k]; }
        cfgViz.writeAdapter();
        for (i = 0; i < page.brandKeys.length; i++) { k = page.brandKeys[i]; brandA[k] = draft[k]; }
        cfgBrand.writeAdapter();
    }

    // throttle live writes: apply immediately, then at most once per interval
    // while the value keeps changing, with a trailing write. drag stays smooth
    // without thrashing the files.
    property bool writePending: false
    Timer {
        id: throttle
        interval: 70
        onTriggered: {
            if (page.writePending) {
                page.writePending = false;
                page.flush();
                throttle.restart();
            }
        }
    }
    function edit(k, v) {
        draft[k] = v;
        if (throttle.running) {
            page.writePending = true;
        } else {
            page.flush();
            throttle.start();
        }
    }

    // islandModules is a list; toggle a module's membership and write it back.
    function toggleIslandModule(id, on) {
        var l = (draft.islandModules || []).slice();
        var i = l.indexOf(id);
        if (on && i < 0) l.push(id);
        else if (!on && i >= 0) l.splice(i, 1);
        page.edit("islandModules", l);
    }

    // each sidebar's panes is an ordered list; toggle a pane's membership on
    // that side and write it back (enable appends to the end, disable removes).
    function toggleSidebarPane(sideKey, id, on) {
        var l = (draft[sideKey] || []).slice();
        var i = l.indexOf(id);
        if (on && i < 0) l.push(id);
        else if (!on && i >= 0) l.splice(i, 1);
        page.edit(sideKey, l);
    }

    function snapshotDraft() {
        var s = {};
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            s[k] = draft[k];
        }
        return s;
    }
    function save() {
        throttle.stop();
        page.writePending = false;
        page.flush();
        page.committedVals = page.snapshotDraft();
    }
    function revert() {
        throttle.stop();
        page.writePending = false;
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            draft[k] = page.committedVals[k];
        }
        page.flush();
    }
    function resetDefaults() {
        for (var i = 0; i < page.keys.length; i++) {
            var k = page.keys[i];
            page.edit(k, page.defaults[k]);
        }
    }

    // enumerate installed font families so the picker only offers fonts that will
    // actually render. one fc-list pass on open; the family is the token before
    // the first comma on each line.
    Process {
        id: fontScan
        command: ["fc-list", ":", "family"]
        Component.onCompleted: running = true
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n");
                var seen = ({});
                var list = [];
                for (var i = 0; i < lines.length; i++) {
                    var fam = lines[i].split(",")[0].trim();
                    if (fam.length > 0 && !seen[fam]) { seen[fam] = true; list.push(fam); }
                }
                if (list.length > 0)
                    page.installedFonts = list;
            }
        }
    }

    FileView {
        id: cfgShell
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/shell.json"
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: { if (!page.shellLoaded) { page.adopt(page.shellKeys, shellA); page.shellLoaded = true; } }
        onLoadFailed: { if (!page.shellLoaded) { page.adopt(page.shellKeys, shellA); page.shellLoaded = true; } }

        JsonAdapter {
            id: shellA
            property real frameRadius: 9
            property real roundness: 10
            property real frameBorder: 59
            property bool frameEnabled: true
            property real frameSmoothing: 8
            property real frameOpacity: 1
            property real shadowStrength: 0.63
            property real shadowSize: 12
            property color surfaceColor: "#0f1115"
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
            property string islandEdge: "top"
            property real islandAlong: -1
            property bool islandHidden: false
            property var islandModules: ["workspaces", "clock", "date", "media"]
            property real islandRadius: 17
            property string fontFamily: "JetBrainsMono Nerd Font"
            property real fontScale: 1.3
            property string weatherLocation: ""
            property string weatherUnit: "auto"
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
        id: cfgViz
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/visualizer.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        atomicWrites: true
        onFileChanged: reload()
        onLoaded: { if (!page.vizLoaded) { page.adopt(page.vizKeys, vizA); page.vizLoaded = true; } else { page.adoptExternal(page.vizKeys, vizA); } }
        onLoadFailed: { if (!page.vizLoaded) { page.adopt(page.vizKeys, vizA); page.vizLoaded = true; } }

        JsonAdapter {
            id: vizA
            property bool enabled: true
            property int bars: 64
            property real height: 0.42
            property real thickness: 0.58
            property real bloom: 0.6
            property real reflection: 0.1
            property bool idleWave: true
            property string style: "bars"
            property string shape: "rounded"
            property string position: "bottom"
            property bool mirror: false
            property int segments: 10
            property int fps: 30
            property bool adaptive: true
            property real smoothing: 0.5
            property real gain: 1.0
            property bool peaks: false
        }
    }

    // brand identity master, edited live like the shell/viz configs; the running
    // shell reads it. Ryoku's own apps ignore it and keep their brand.
    FileView {
        id: cfgBrand
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/brand.json"
        blockLoading: true
        watchChanges: false
        printErrors: false
        atomicWrites: true
        onLoaded: { if (!page.brandLoaded) { page.adopt(page.brandKeys, brandA); page.brandLoaded = true; } }
        onLoadFailed: { if (!page.brandLoaded) { page.adopt(page.brandKeys, brandA); page.brandLoaded = true; } }

        JsonAdapter {
            id: brandA
            property string markText: "\u529b"
            property string markImage: ""
            property bool markTint: true
            property string name: "Ryoku"
        }
    }

    // OS file picker for a custom logo image (SVG or raster).
    FileDialog {
        id: logoPicker
        title: "Choose a logo image"
        nameFilters: ["Images (*.svg *.png *.jpg *.jpeg *.webp)", "All files (*)"]
        onAccepted: page.edit("markImage", "" + logoPicker.selectedFile)
    }

    // leaving the section (or closing the hub) with unsaved edits puts the
    // saved look back, so a preview is never left applied by accident.
    Component.onDestruction: {
        if (page.ready && page.dirty) {
            var i, k;
            for (i = 0; i < page.shellKeys.length; i++) { k = page.shellKeys[i]; shellA[k] = page.committedVals[k]; }
            cfgShell.writeAdapter();
            for (i = 0; i < page.vizKeys.length; i++) { k = page.vizKeys[i]; vizA[k] = page.committedVals[k]; }
            cfgViz.writeAdapter();
            for (i = 0; i < page.brandKeys.length; i++) { k = page.brandKeys[i]; brandA[k] = page.committedVals[k]; }
            cfgBrand.writeAdapter();
        }
    }
    // The view is the schema. The 66 settings used to be declared five times
    // over (a key array, a defaults literal, a draft property, an adapter
    // property, and the row itself, with the key restated as a bare string in
    // every closure); the rows are now data and this draws them.
    SchemaPage {
        anchors.fill: parent
        schema: Schema.rows
        draft: draft
        defaults: page.defaults
        // Hub.qml still draws PageHeader above this. Until the chrome is
        // ported, the page must not draw its own or the title renders twice.
        onEdited: (k, v) => page.edit(k, v)
    }
}
