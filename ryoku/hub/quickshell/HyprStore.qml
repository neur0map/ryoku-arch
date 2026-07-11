pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// shared engine behind every Lua-editing settings page. loads the full override
// document from the `ryoku-hub hypr` backend, holds an editable draft as plain
// reactive properties, previews scalar edits live (flash-free, via the backend's
// `hyprctl eval`), persists on save (which regenerates settings.lua and reloads,
// locking in list changes too). pages bind controls to these properties and call
// edit() / editList() / save() / revert() / reset(); the action bar reads `dirty`
// and `ready`. leaving a page with unsaved edits drops the preview.
Item {
    id: store

    property bool ready: false
    // last-saved doc + shipped defaults, as plain JS objects.
    property var committed: ({})
    property var defaults: ({})

    // draft: appearance. initial values mirror defaultOverrides() in the Go
    // backend (the shipped decoration.lua baseline); adopt() replaces them as
    // soon as `hypr get` returns.
    property int gapsIn: 12
    property int gapsOut: 18
    property int borderSize: 2
    property int rounding: 2
    property real roundingPower: 4
    property real activeOpacity: 1
    property real inactiveOpacity: 0.94
    property bool dimInactive: false
    property real dimStrength: 0.5
    property bool blurEnabled: true
    property int blurSize: 4
    property int blurPasses: 1
    property bool blurXray: false
    property real blurVibrancy: 0.17
    property real blurNoise: 0.01
    property bool shadowEnabled: true
    property int shadowRange: 45
    property int shadowPower: 4
    property bool glowEnabled: false
    property int glowRange: 10
    property string glowColor: "#ee33cc"
    property bool animations: true
    property string layout: "dwindle"
    property string activeBorder: "#e0563b"
    property string inactiveBorder: "#313a4d"
    property bool resizeOnBorder: true
    property bool snapEnabled: false
    property bool wobblyWindows: false
    property string windowStyle: "pop"
    property bool animatedBorder: false
    property real borderAngleSpeed: 3

    // draft: input.
    property string kbLayout: "us"
    property string kbVariant: ""
    property string kbOptions: ""
    property bool numlockByDefault: false
    property int followMouse: 2
    property real sensitivity: 0
    property string accelProfile: ""
    property bool leftHanded: false
    property bool mouseNaturalScroll: false
    property real mouseScrollFactor: 1
    property bool middleClickPaste: true
    property bool naturalScroll: false
    property bool tapToClick: true
    property bool tapAndDrag: true
    property bool clickfinger: false
    property bool middleEmulation: false
    property real touchScrollFactor: 1
    property bool disableWhileTyping: true
    property int repeatRate: 25
    property int repeatDelay: 600
    property bool workspaceSwipe: false
    property int swipeFingers: 3
    property bool swipeInvert: true
    property bool swipeCreateNew: true
    property int swipeDistance: 300

    // draft: cursor.
    property string cursorTheme: "Bibata-Modern-Ice"
    property int cursorSize: 24
    property int cursorInactiveTimeout: 0
    property bool cursorHideOnKeyPress: false

    // draft: lists.
    property var env: []
    property var windowRules: []
    property var layerRules: []
    property var appOverrides: []
    property var autostart: []
    property var keybinds: []

    // draft: plugins (Hyprland compositor plugins). nested object mirroring the
    // Go Plugins struct; applied on Save, not live-previewed (a plugin loads on
    // reload). hyprscrolling has no enable of its own: it follows the scrolling
    // tiling layout, these are just its knobs.
    property var plugins: ({
        "dynamicCursors": { "enabled": false, "mode": "tilt", "shake": true, "magnify": 4 },
        "hyprbars": { "enabled": false, "height": 26, "textSize": 11, "blur": true, "buttons": true },
        "imgborders": { "enabled": false, "image": "", "sizes": "8,8,8,8", "insets": "0,0,0,0", "scale": 1, "smooth": true },
        "hyprglass": { "enabled": false, "preset": "clear", "blurStrength": 2, "opacity": 1, "tint": "8899aa22" },
        "hyprfocus": { "enabled": false, "mode": "flash", "opacity": 0.8, "bounce": 0.95, "slide": 20 },
        "hyprscrolling": { "columnWidth": 0.5, "followFocus": true }
    })

    // animations = per-leaf overrides + user bezier curves. unlike the other
    // lists, these DO preview live (curves + animations apply via hyprctl eval).
    property var animItems: []
    property var animCurves: []

    // bump on every draft change so `dirty` re-evals. (editList already reassigns
    // the JS array which triggers, but scalar edits route through this too.)
    property int rev: 0

    // one key list per domain: store property name == backend JSON key. cursor
    // keys live on the store as cursor<Key> to avoid clashing with appearance.
    readonly property var appearanceKeys: [
        "gapsIn", "gapsOut", "borderSize", "rounding", "roundingPower",
        "activeOpacity", "inactiveOpacity", "dimInactive", "dimStrength",
        "blurEnabled", "blurSize", "blurPasses", "blurXray", "blurVibrancy", "blurNoise",
        "shadowEnabled", "shadowRange", "shadowPower",
        "glowEnabled", "glowRange", "glowColor",
        "animations", "layout", "activeBorder", "inactiveBorder",
        "resizeOnBorder", "snapEnabled",
        "wobblyWindows", "windowStyle", "animatedBorder", "borderAngleSpeed"
    ]
    readonly property var inputKeys: [
        "kbLayout", "kbVariant", "kbOptions", "numlockByDefault",
        "followMouse", "sensitivity", "accelProfile", "leftHanded",
        "mouseNaturalScroll", "mouseScrollFactor", "middleClickPaste",
        "naturalScroll", "tapToClick", "tapAndDrag", "clickfinger",
        "middleEmulation", "touchScrollFactor", "disableWhileTyping",
        "repeatRate", "repeatDelay",
        "workspaceSwipe", "swipeFingers", "swipeInvert", "swipeCreateNew", "swipeDistance"
    ]
    readonly property var cursorKeys: ["theme", "size", "inactiveTimeout", "hideOnKeyPress"]

    function cursorProp(k) { return "cursor" + k.charAt(0).toUpperCase() + k.slice(1); }

    function snapshot() {
        var a = {}, i = {}, c = {};
        for (var n = 0; n < store.appearanceKeys.length; n++)
            a[store.appearanceKeys[n]] = store[store.appearanceKeys[n]];
        for (n = 0; n < store.inputKeys.length; n++)
            i[store.inputKeys[n]] = store[store.inputKeys[n]];
        for (n = 0; n < store.cursorKeys.length; n++)
            c[store.cursorKeys[n]] = store[store.cursorProp(store.cursorKeys[n])];
        return {
            "appearance": a, "input": i, "cursor": c,
            "env": store.env, "windowRules": store.windowRules, "layerRules": store.layerRules,
            "appOverrides": store.appOverrides,
            "autostart": store.autostart, "keybinds": store.keybinds,
            "anim": { "items": store.animItems, "curves": store.animCurves },
            "plugins": store.plugins
        };
    }

    // adopt expects a complete doc (the backend always marshals every field;
    // a partial store was already overlaid on the defaults in Go).
    function adopt(o) {
        var a = o.appearance || {}, i = o.input || {}, c = o.cursor || {};
        for (var n = 0; n < store.appearanceKeys.length; n++)
            if (a[store.appearanceKeys[n]] !== undefined)
                store[store.appearanceKeys[n]] = a[store.appearanceKeys[n]];
        for (n = 0; n < store.inputKeys.length; n++)
            if (i[store.inputKeys[n]] !== undefined)
                store[store.inputKeys[n]] = i[store.inputKeys[n]];
        for (n = 0; n < store.cursorKeys.length; n++)
            if (c[store.cursorKeys[n]] !== undefined)
                store[store.cursorProp(store.cursorKeys[n])] = c[store.cursorKeys[n]];
        store.env = o.env || []; store.windowRules = o.windowRules || []; store.layerRules = o.layerRules || [];
        store.appOverrides = o.appOverrides || [];
        store.autostart = o.autostart || []; store.keybinds = o.keybinds || [];
        var an = o.anim || {};
        store.animItems = an.items || []; store.animCurves = an.curves || [];
        store.plugins = o.plugins || store.plugins;
        store.rev++;
    }

    readonly property bool dirty: {
        void store.rev;
        return store.ready && JSON.stringify(store.snapshot()) !== JSON.stringify(store.committed);
    }

    // scalar edit: apply to draft, preview it live (throttled).
    function edit(key, value) {
        store[key] = value;
        store.rev++;
        store.queuePreview();
    }

    // list edit: replace a whole list. lists are NOT previewed, they land on Save
    // (which reloads).
    function editList(key, arr) {
        store[key] = arr;
        store.rev++;
    }

    // animation list edit: same as editList, but previews live.
    function editAnim(key, arr) {
        store[key] = arr;
        store.rev++;
        store.queuePreview();
    }

    // live preview throttle (mirrors ShellSettingsPage).
    property bool previewPending: false
    Timer {
        id: throttle
        interval: 80
        onTriggered: {
            if (store.previewPending) {
                store.previewPending = false;
                store.previewNow();
                throttle.restart();
            }
        }
    }
    function queuePreview() {
        if (throttle.running) {
            store.previewPending = true;
        } else {
            store.previewNow();
            throttle.start();
        }
    }
    function previewNow() {
        previewProc.command = ["ryoku-hub", "hypr", "preview", JSON.stringify(store.snapshot())];
        previewProc.running = true;
    }

    function save() {
        throttle.stop();
        store.previewPending = false;
        saveProc.command = ["ryoku-hub", "hypr", "save", JSON.stringify(store.snapshot())];
        saveProc.running = true;
        store.committed = JSON.parse(JSON.stringify(store.snapshot()));
        store.rev++;
    }
    function revert() {
        throttle.stop();
        store.previewPending = false;
        store.adopt(store.committed);
        // reload to reset the live session to the saved state exactly. eval
        // can't push some keywords back to a default and can't re-derive wallpaper
        // border colours, so we need the regen path. page is alive here, so the
        // process runs.
        restoreProc.command = ["ryoku-hub", "hypr", "restore"];
        restoreProc.running = true;
    }
    // reset is per-domain so a page never clobbers another's settings. the store
    // holds the whole doc; an Appearance reset must leave user env/rules alone.
    function resetAppearance() {
        var a = store.defaults.appearance || {}, c = store.defaults.cursor || {};
        for (var n = 0; n < store.appearanceKeys.length; n++)
            if (a[store.appearanceKeys[n]] !== undefined)
                store[store.appearanceKeys[n]] = a[store.appearanceKeys[n]];
        for (n = 0; n < store.cursorKeys.length; n++)
            if (c[store.cursorKeys[n]] !== undefined)
                store[store.cursorProp(store.cursorKeys[n])] = c[store.cursorKeys[n]];
        // the plugin toggles live on the Appearance tabs (Cursor/Look/Borders),
        // so a "Reset to defaults" there returns them (and hyprfocus) to off too.
        store.resetPlugins();
        store.rev++;
        store.queuePreview();
    }
    function resetInput() {
        var i = store.defaults.input || {};
        for (var n = 0; n < store.inputKeys.length; n++)
            if (i[store.inputKeys[n]] !== undefined)
                store[store.inputKeys[n]] = i[store.inputKeys[n]];
        store.rev++;
        store.queuePreview();
    }
    // plugin edit: set draft[section][key] on a copy, reassign to trigger the
    // reactive dirty check. no live preview -- plugins load on reload, so they
    // land on Save.
    function editPlugin(section, key, value) {
        var p = JSON.parse(JSON.stringify(store.plugins));
        if (!p[section])
            p[section] = {};
        p[section][key] = value;
        store.plugins = p;
        store.rev++;
    }
    function resetPlugins() {
        if (store.defaults.plugins)
            store.plugins = JSON.parse(JSON.stringify(store.defaults.plugins));
        store.rev++;
    }

    Process { id: previewProc }
    Process { id: saveProc }
    Process { id: restoreProc }

    Process {
        id: defProc
        command: ["ryoku-hub", "hypr", "defaults"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { store.defaults = JSON.parse(this.text); } catch (e) {}
            }
        }
    }

    Process {
        id: getProc
        command: ["ryoku-hub", "hypr", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    store.adopt(o);
                    store.committed = JSON.parse(JSON.stringify(store.snapshot()));
                    store.ready = true;
                } catch (e) {
                    console.log("hub: hypr get parse failed: " + e);
                }
            }
        }
    }
}
