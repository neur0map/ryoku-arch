pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Io

// The shared engine behind every Lua-editing settings page. It loads the full
// override document from the `ryoku-hub hypr` backend, holds an editable draft as
// plain reactive properties, previews scalar edits live (flash-free, via the
// backend's `hyprctl eval`), and persists on save (which regenerates settings.lua
// and reloads, locking in list changes too). Pages bind their controls to these
// properties and call edit()/editList()/save()/revert()/reset(); the action bar
// reads `dirty` and `ready`. Leaving a page with unsaved edits drops the preview.
Item {
    id: store

    property bool ready: false
    // The last-saved document and the shipped defaults, as plain JS objects.
    property var committed: ({})
    property var defaults: ({})

    // --- draft: appearance ---
    property int gapsIn: 8
    property int gapsOut: 26
    property int borderSize: 3
    property int rounding: 16
    property real activeOpacity: 0.96
    property real inactiveOpacity: 0.90
    property bool blurEnabled: true
    property int blurSize: 8
    property int blurPasses: 3
    property bool shadowEnabled: true
    property int shadowRange: 30
    property bool animations: true
    property string layout: "dwindle"
    property bool followWallpaper: true
    property string activeBorder: "#e0563b"
    property string inactiveBorder: "#313a4d"

    // --- draft: input ---
    property string kbLayout: "us"
    property string kbVariant: ""
    property string kbOptions: ""
    property int followMouse: 1
    property real sensitivity: 0
    property string accelProfile: ""
    property bool naturalScroll: false
    property bool tapToClick: true
    property bool disableWhileTyping: true
    property int repeatRate: 25
    property int repeatDelay: 600
    property bool workspaceSwipe: false
    property int swipeFingers: 3

    // --- draft: cursor ---
    property string cursorTheme: "Bibata-Modern-Ice"
    property int cursorSize: 24

    // --- draft: lists ---
    property var env: []
    property var windowRules: []
    property var layerRules: []
    property var autostart: []
    property var keybinds: []

    // Animations: per-leaf overrides and user bezier curves. Unlike the other
    // lists, these preview live (curves and animations apply via hyprctl eval).
    property var animItems: []
    property var animCurves: []

    // Bump on every draft change so `dirty` re-evaluates (JS arrays reassigned in
    // editList already trigger, but scalar edits go through this too).
    property int rev: 0

    function snapshot() {
        return {
            "appearance": {
                "gapsIn": store.gapsIn, "gapsOut": store.gapsOut, "borderSize": store.borderSize,
                "rounding": store.rounding, "activeOpacity": store.activeOpacity,
                "inactiveOpacity": store.inactiveOpacity, "blurEnabled": store.blurEnabled,
                "blurSize": store.blurSize, "blurPasses": store.blurPasses,
                "shadowEnabled": store.shadowEnabled, "shadowRange": store.shadowRange,
                "animations": store.animations, "layout": store.layout,
                "followWallpaper": store.followWallpaper,
                "activeBorder": store.activeBorder, "inactiveBorder": store.inactiveBorder
            },
            "input": {
                "kbLayout": store.kbLayout, "kbVariant": store.kbVariant, "kbOptions": store.kbOptions,
                "followMouse": store.followMouse, "sensitivity": store.sensitivity,
                "accelProfile": store.accelProfile, "naturalScroll": store.naturalScroll,
                "tapToClick": store.tapToClick, "disableWhileTyping": store.disableWhileTyping,
                "repeatRate": store.repeatRate, "repeatDelay": store.repeatDelay,
                "workspaceSwipe": store.workspaceSwipe, "swipeFingers": store.swipeFingers
            },
            "cursor": { "theme": store.cursorTheme, "size": store.cursorSize },
            "env": store.env, "windowRules": store.windowRules, "layerRules": store.layerRules,
            "autostart": store.autostart, "keybinds": store.keybinds,
            "anim": { "items": store.animItems, "curves": store.animCurves }
        };
    }

    function adopt(o) {
        var a = o.appearance || {}, i = o.input || {}, c = o.cursor || {};
        store.gapsIn = a.gapsIn; store.gapsOut = a.gapsOut; store.borderSize = a.borderSize;
        store.rounding = a.rounding; store.activeOpacity = a.activeOpacity;
        store.inactiveOpacity = a.inactiveOpacity; store.blurEnabled = a.blurEnabled;
        store.blurSize = a.blurSize; store.blurPasses = a.blurPasses;
        store.shadowEnabled = a.shadowEnabled; store.shadowRange = a.shadowRange;
        store.animations = a.animations; store.layout = a.layout;
        store.followWallpaper = a.followWallpaper;
        store.activeBorder = a.activeBorder; store.inactiveBorder = a.inactiveBorder;
        store.kbLayout = i.kbLayout; store.kbVariant = i.kbVariant; store.kbOptions = i.kbOptions;
        store.followMouse = i.followMouse; store.sensitivity = i.sensitivity;
        store.accelProfile = i.accelProfile; store.naturalScroll = i.naturalScroll;
        store.tapToClick = i.tapToClick; store.disableWhileTyping = i.disableWhileTyping;
        store.repeatRate = i.repeatRate; store.repeatDelay = i.repeatDelay;
        store.workspaceSwipe = !!i.workspaceSwipe; store.swipeFingers = i.swipeFingers || 3;
        store.cursorTheme = c.theme; store.cursorSize = c.size;
        store.env = o.env || []; store.windowRules = o.windowRules || []; store.layerRules = o.layerRules || [];
        store.autostart = o.autostart || []; store.keybinds = o.keybinds || [];
        var an = o.anim || {};
        store.animItems = an.items || []; store.animCurves = an.curves || [];
        store.rev++;
    }

    readonly property bool dirty: {
        void store.rev;
        return store.ready && JSON.stringify(store.snapshot()) !== JSON.stringify(store.committed);
    }

    // Scalar edit: apply to the draft and preview it live (throttled).
    function edit(key, value) {
        store[key] = value;
        store.rev++;
        store.queuePreview();
    }

    // List edit: replace a whole list. Lists are not previewed; they take effect
    // on Save (which reloads).
    function editList(key, arr) {
        store[key] = arr;
        store.rev++;
    }

    // Animation list edit: like editList, but previews live.
    function editAnim(key, arr) {
        store[key] = arr;
        store.rev++;
        store.queuePreview();
    }

    // --- live preview throttle (mirrors ShellSettingsPage) ---
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
        // Reload to reset the live session to the saved state exactly (eval cannot
        // push some keywords back to a default, and cannot re-derive wallpaper
        // border colours). The page is alive here, so the process runs.
        restoreProc.command = ["ryoku-hub", "hypr", "restore"];
        restoreProc.running = true;
    }
    // Reset is per-domain so a page never clobbers another's settings (the store
    // holds the whole document; an Appearance reset must leave user env/rules alone).
    function resetAppearance() {
        var a = store.defaults.appearance || {}, c = store.defaults.cursor || {};
        store.gapsIn = a.gapsIn; store.gapsOut = a.gapsOut; store.borderSize = a.borderSize;
        store.rounding = a.rounding; store.activeOpacity = a.activeOpacity;
        store.inactiveOpacity = a.inactiveOpacity; store.blurEnabled = a.blurEnabled;
        store.blurSize = a.blurSize; store.blurPasses = a.blurPasses;
        store.shadowEnabled = a.shadowEnabled; store.shadowRange = a.shadowRange;
        store.animations = a.animations; store.layout = a.layout;
        store.followWallpaper = a.followWallpaper;
        store.activeBorder = a.activeBorder; store.inactiveBorder = a.inactiveBorder;
        store.cursorTheme = c.theme; store.cursorSize = c.size;
        store.rev++;
        store.queuePreview();
    }
    function resetInput() {
        var i = store.defaults.input || {};
        store.kbLayout = i.kbLayout; store.kbVariant = i.kbVariant; store.kbOptions = i.kbOptions;
        store.followMouse = i.followMouse; store.sensitivity = i.sensitivity;
        store.accelProfile = i.accelProfile; store.naturalScroll = i.naturalScroll;
        store.tapToClick = i.tapToClick; store.disableWhileTyping = i.disableWhileTyping;
        store.repeatRate = i.repeatRate; store.repeatDelay = i.repeatDelay;
        store.rev++;
        store.queuePreview();
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
