pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../schema/WindowsPage.js" as Schema

// Windows: everything about a Hyprland window in one place -- Layout (tiling,
// gaps, behaviour), Look (shape, opacity, blur, shadows, title bars, glow,
// glass), Borders (thickness, colours, gradient, image) and Motion (open/close,
// wobble, focus). Every setting rides the hypr draft (hub.hyprVal/hyprEdit); the
// write ledger and Save belong to the shell. Rendered from the schema through the
// shared SchemaPage, so the deep knobs fold under the rail's Advanced switch and
// the bento grid handles space. A dependent row hides until its parent is on.
Item {
    id: pg
    property var hub

    readonly property string pTitle: I18n.tr("Windows")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("How your windows look and behave: layout, shape, blur, shadows, borders, and motion.")

    readonly property bool ready: pg.hub ? pg.hub.hyprLoaded === true : false
    function hv(path) { return pg.hub ? pg.hub.hyprVal(path) : undefined }
    function cv(path) { return pg.hub ? pg.hub.hyprCommittedVal(path) : undefined }

    // Which compositor plugins are actually installed. The probe below lists the
    // .so files present in either plugin dir into availablePlugins; until it
    // returns, probed is false and every plugin row shows (fail-open, no empty
    // flash). Once probed, a plugin whose .so is absent has its rows gated out,
    // so the Plugins tab lists only what is installed.
    property var availablePlugins: ({})
    property bool probed: false

    // the .so a plugin key needs, "" for non-plugin keys. hyprscrolling is a core
    // layout (no .so), so it is deliberately unmapped and never gated here.
    function pluginSo(key) {
        if (key === undefined || key === null) return "";
        if (key.indexOf("plugins.hyprbars.") === 0) return "hyprbars.so";
        if (key.indexOf("plugins.hyprglass.") === 0) return "hyprglass.so";
        if (key.indexOf("plugins.imgborders.") === 0) return "imgborders.so";
        if (key.indexOf("plugins.dynamicCursors.") === 0) return "dynamic-cursors.so";
        if (key.indexOf("plugins.hyprfocus.") === 0) return "hyprfocus.so";
        return "";
    }

    // per-row visibility: a dependent stays hidden until its parent toggle is on
    // or the relevant layout is selected. Mirrors the gates the settings carried
    // when they lived on the Appearance page.
    function gateOk(key, d) {
        // auto-detect: hide a plugin's rows once the probe confirms its .so is
        // absent; before the probe returns (probed false) they show (fail-open).
        var so = pg.pluginSo(key);
        if (so !== "" && pg.probed && pg.availablePlugins[so] !== true)
            return false;
        switch (key) {
        case "dwindle.preserveSplit": case "dwindle.smartSplit": case "dwindle.smartResizing":
        case "dwindle.defaultSplitRatio": case "dwindle.forceSplit": case "dwindle.useActiveForSplits":
            return d["appearance.layout"] === "dwindle";
        case "master.mfact": case "master.newStatus": case "master.newOnTop":
        case "master.orientation": case "master.smartResizing":
            return d["appearance.layout"] === "master";
        case "plugins.hyprscrolling.columnWidth": case "plugins.hyprscrolling.followFocus":
            return d["appearance.layout"] === "scrolling";
        case "plugins.hyprbars.height": case "plugins.hyprbars.textSize":
        case "plugins.hyprbars.blur": case "plugins.hyprbars.buttons":
            return d["plugins.hyprbars.enabled"] === true;
        case "appearance.dimStrength": return d["appearance.dimInactive"] === true;
        case "appearance.wobblyWindows": case "appearance.windowStyle": return d["appearance.animations"] === true;
        case "appearance.glowRange": case "appearance.glowColor": return d["appearance.glowEnabled"] === true;
        case "appearance.borderAngleSpeed": return d["appearance.animatedBorder"] === true;
        case "plugins.hyprglass.preset": case "plugins.hyprglass.blurStrength": case "plugins.hyprglass.opacity":
        case "plugins.hyprglass.brightness": case "plugins.hyprglass.theme": case "plugins.hyprglass.tint":
            return d["plugins.hyprglass.enabled"] === true;
        case "plugins.imgborders.image": case "plugins.imgborders.scale": case "plugins.imgborders.smooth":
        case "plugins.imgborders.blur": case "plugins.imgborders.sizes": case "plugins.imgborders.insets":
            return d["plugins.imgborders.enabled"] === true;
        case "appearance.blurContrast": case "appearance.blurBrightness": case "appearance.blurSpecial":
        case "appearance.blurPopups": case "appearance.blurIgnoreOpacity": case "appearance.blurNewOptimizations":
        case "appearance.blurVibrancyDarkness":
            return d["appearance.blurEnabled"] === true;
        case "appearance.shadowSharp": case "appearance.shadowScale": case "appearance.shadowColor":
            return d["appearance.shadowEnabled"] === true;
        }
        return true;
    }

    // draft/committed are flat maps off the hypr store (dotted keys), the shape
    // the settings sheet reads. draft depends on hyprVal, so an edit rebuilds it.
    readonly property var draft: {
        var d = {};
        if (pg.hub)
            for (var i = 0; i < Schema.rows.length; i++) { var k = Schema.rows[i].key; if (k) d[k] = pg.hv(k); }
        return d;
    }
    readonly property var committed: {
        var d = {};
        if (pg.hub)
            for (var i = 0; i < Schema.rows.length; i++) { var k = Schema.rows[i].key; if (k) d[k] = pg.cv(k); }
        return d;
    }
    readonly property var settingsSchema: {
        var d = pg.draft, out = [];
        for (var i = 0; i < Schema.rows.length; i++)
            if (pg.gateOk(Schema.rows[i].key, d)) out.push(Schema.rows[i]);
        return out;
    }

    // probe both plugin dirs for the shipped .so files and record which are
    // present, driving availablePlugins/probed that gateOk reads to auto-hide
    // rows for plugins that are not installed. one sh -c covers both dirs and all
    // five names; StdioCollector gathers the printed basenames into a set.
    Process {
        running: true
        command: ["sh", "-c",
            "for d in /usr/lib/hyprland/plugins \"$HOME/.local/lib/hyprland/plugins\"; do for n in dynamic-cursors hyprbars hyprfocus hyprglass imgborders; do [ -e \"$d/$n.so\" ] && echo \"$n.so\"; done; done"]
        stdout: StdioCollector {
            onStreamFinished: {
                var set = {};
                var lines = ("" + this.text).split("\n");
                for (var i = 0; i < lines.length; i++) {
                    var s = lines[i].trim();
                    if (s !== "") set[s] = true;
                }
                pg.availablePlugins = set;
                pg.probed = true;
            }
        }
    }

    function focusKey(k) { sp.focusKey(k) }
    SchemaPage {
        id: sp
        anchors.fill: parent
        schema: pg.settingsSchema
        draft: pg.draft
        defaults: pg.committed
        advanced: pg.hub ? pg.hub.advanced : false
        title: pg.pTitle
        eyebrow: pg.pEyebrow
        blurb: pg.pBlurb
        query: pg.hub ? pg.hub.query : ""
        onEdited: (k, v) => { if (pg.hub) pg.hub.hyprEdit(k, v); }
        onPickRequested: (r) => { if (pg.hub) pg.hub.openPick(r); }
    }
}
