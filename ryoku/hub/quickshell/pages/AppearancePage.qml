pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import "../schema/AppearancePage.js" as Schema
import ".."

// Appearance (DESIGN.md, DESKTOP). The system look and feel, ported to the
// beta18 monochrome instrument. Look/Borders/Cursor are the live Hyprland draft
// rendered through the shared settings sheet and persisted by the shell's hypr
// store (hyprVal/hyprEdit). The instant-apply surfaces the old page carried
// survive as their own monochrome sub-views: Rices (browse/detail/apply via
// ryoku-hub rice), the wallpaper gallery + theme scheme (ryoku-shell /
// ryoku-hub hypr scheme), the cursor theme catalogue (ryoku-hub hypr cursors),
// and Comfort (brightnessctl, night light). The shell owns the rail, the pinned
// preview, the pending-write diff and the Save/Revert action bar; nothing here
// writes hypr to disk except through that bar. Every value is a Token; the only
// colour is the wallpaper and rice specimens, which are the thing the user is
// choosing and so read as data (DESIGN.md section 1).
Item {
    id: pg

    property var hub

    readonly property string pTitle: I18n.tr("Appearance")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("Windows, borders, cursor, wallpaper, and comfort, applied to your desktop as you make them.")

    // ── the hypr draft, flattened to the schema keys the sheet reads ────────
    // draft/committed are dotted-path reads off the shell's whole-document hypr
    // store; only the real hypr keys are pulled (the Wallpaper/Comfort rows have
    // no hypr home and are driven by their own tools below).
    readonly property var draft: {
        var d = {};
        if (pg.hub) {
            for (var i = 0; i < Schema.rows.length; i++) {
                var k = Schema.rows[i].key;
                if (k && /^(appearance|plugins|cursor|dwindle|master)\./.test(k))
                    d[k] = pg.hub.hyprVal(k);
            }
        }
        return d;
    }
    readonly property var committed: {
        var d = {};
        if (pg.hub) {
            for (var i = 0; i < Schema.rows.length; i++) {
                var k = Schema.rows[i].key;
                if (k && /^(appearance|plugins|cursor|dwindle|master)\./.test(k))
                    d[k] = pg.hub.hyprCommittedVal(k);
            }
        }
        return d;
    }
    function setKey(k, v) { if (pg.hub) pg.hub.hyprEdit(k, v); }

    // the sheet-fed schema: Look/Borders/Cursor only, gated exactly as the old
    // page gated its rows (a parent toggle hides its dependents), with the
    // cursor theme promoted to a catalogue pick over the scanned icon sets.
    readonly property var settingsSchema: {
        var d = pg.draft;
        var out = [];
        for (var i = 0; i < Schema.rows.length; i++) {
            var r = Schema.rows[i];
            if (r.tab !== "Windows" && r.tab !== "Effects" && r.tab !== "Borders" && r.tab !== "Cursor")
                continue;
            if (!pg.gateOk(r.key, d))
                continue;
            if (r.key === "cursor.theme")
                out.push({ tab: r.tab, group: r.group, key: r.key, label: r.label,
                           desc: r.desc, ctl: "pick", src: "hypr", opts: pg.cursorThemes });
            else
                out.push({ tab: r.tab, group: r.group, key: r.key, label: r.label,
                           desc: r.desc, ctl: r.ctl, src: "hypr", opts: r.opts,
                           lo: r.lo, hi: r.hi, unit: r.unit, pct: r.pct });
        }
        return out;
    }

    // the per-row visibility the old page expressed with inline `visible:`.
    // blurEnabled/shadowEnabled deliberately do NOT gate their siblings.
    function gateOk(key, d) {
        switch (key) {
        case "plugins.hyprscrolling.columnWidth":
        case "plugins.hyprscrolling.followFocus":
            return d["appearance.layout"] === "scrolling";
        case "plugins.hyprbars.height":
        case "plugins.hyprbars.textSize":
        case "plugins.hyprbars.blur":
        case "plugins.hyprbars.buttons":
            return d["plugins.hyprbars.enabled"] === true;
        case "appearance.dimStrength":
            return d["appearance.dimInactive"] === true;
        case "appearance.wobblyWindows":
        case "appearance.windowStyle":
            return d["appearance.animations"] === true;
        case "appearance.glowRange":
        case "appearance.glowColor":
            return d["appearance.glowEnabled"] === true;
        case "plugins.hyprglass.preset":
        case "plugins.hyprglass.blurStrength":
        case "plugins.hyprglass.opacity":
        case "plugins.hyprglass.brightness":
        case "plugins.hyprglass.theme":
        case "plugins.hyprglass.tint":
            return d["plugins.hyprglass.enabled"] === true;
        case "appearance.activeBorder":
        case "appearance.inactiveBorder":
            return pg.scheme !== "follow";
        case "appearance.borderAngleSpeed":
            return d["appearance.animatedBorder"] === true;
        case "plugins.imgborders.image":
        case "plugins.imgborders.scale":
        case "plugins.imgborders.smooth":
        case "plugins.imgborders.blur":
        case "plugins.imgborders.sizes":
        case "plugins.imgborders.insets":
            return d["plugins.imgborders.enabled"] === true;
        case "plugins.dynamicCursors.mode":
        case "plugins.dynamicCursors.shake":
            return d["plugins.dynamicCursors.enabled"] === true;
        case "appearance.blurContrast":
        case "appearance.blurBrightness":
        case "appearance.blurSpecial":
        case "appearance.blurPopups":
        case "appearance.blurIgnoreOpacity":
        case "appearance.blurNewOptimizations":
        case "appearance.blurVibrancyDarkness":
            return d["appearance.blurEnabled"] === true;
        case "appearance.shadowSharp":
        case "appearance.shadowScale":
        case "appearance.shadowColor":
            return d["appearance.shadowEnabled"] === true;
        case "dwindle.preserveSplit":
        case "dwindle.smartSplit":
        case "dwindle.smartResizing":
        case "dwindle.defaultSplitRatio":
        case "dwindle.forceSplit":
        case "dwindle.useActiveForSplits":
            return d["appearance.layout"] === "dwindle";
        case "master.mfact":
        case "master.newStatus":
        case "master.newOnTop":
        case "master.orientation":
        case "master.smartResizing":
            return d["appearance.layout"] === "master";
        case "plugins.dynamicCursors.magnify":
            return d["plugins.dynamicCursors.enabled"] === true && d["plugins.dynamicCursors.shake"] === true;
        }
        return true;
    }

    property string tab: "Windows"
    readonly property var tabs: ["Windows", "Effects", "Borders", "Cursor", "Theme", "Comfort", "Rices"]
    readonly property bool settingsTab: pg.tab === "Windows" || pg.tab === "Effects" || pg.tab === "Borders" || pg.tab === "Cursor"
    readonly property bool searching: pg.hub ? (pg.hub.query || "") !== "" : false

    readonly property string home: Quickshell.env("HOME") || ""

    // ════════════════════════════════════════════════════════════════════════
    // Cursor: the theme list is scanned at runtime, so it is a catalogue pick,
    // not an enum. The size/idle/hide/motion rows ride the settings sheet.
    // ════════════════════════════════════════════════════════════════════════
    property var cursorThemes: []
    Process {
        id: cursorsProc
        command: ["ryoku-hub", "hypr", "cursors"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { pg.cursorThemes = JSON.parse(this.text); } catch (e) {} }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Theme palette scheme: follow the wallpaper, or lock light/dark. Instant,
    // via `ryoku-hub hypr scheme`; never touches the hypr draft or Save.
    // ════════════════════════════════════════════════════════════════════════
    property string scheme: "follow"
    function setScheme(k) {
        pg.scheme = k;
        schemeApplyProc.command = ["ryoku-hub", "hypr", "scheme", k];
        schemeApplyProc.running = true;
    }
    Process {
        id: schemeQueryProc
        command: ["ryoku-hub", "hypr", "scheme"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { pg.scheme = JSON.parse(this.text).scheme || "follow"; } catch (e) {} }
        }
    }
    Process { id: schemeApplyProc; stdout: StdioCollector { onStreamFinished: schemeQueryProc.running = true } }

    // Theme apps: extend the palette to GTK / GUI apps (theme.json themeApps),
    // instant via `ryoku-hub hypr theme-apps`. Governs the reach past the shell
    // (Files, editors, GTK apps); the shell, terminal, borders and Qt always
    // track the palette. Sits under the scheme, the same instant-apply family.
    property bool themeApps: true
    function setThemeApps(v) {
        pg.themeApps = v;
        themeAppsApplyProc.command = ["ryoku-hub", "hypr", "theme-apps", v ? "on" : "off"];
        themeAppsApplyProc.running = true;
    }
    Process {
        id: themeAppsQueryProc
        command: ["ryoku-hub", "hypr", "theme-apps"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { pg.themeApps = JSON.parse(this.text).themeApps !== false; } catch (e) {} }
        }
    }
    Process { id: themeAppsApplyProc; stdout: StdioCollector { onStreamFinished: themeAppsQueryProc.running = true } }

    // Ryoku default: reset the whole desktop to the shipped signature (stele
    // bar, square corners, Space Grotesk, grainy mono) in one click, via
    // `ryoku-hub hypr ryoku-theme`. Instant and live, like the scheme apply.
    function applyRyokuTheme() { ryokuThemeProc.running = true; }
    Process { id: ryokuThemeProc; command: ["ryoku-hub", "hypr", "ryoku-theme"]; stdout: StdioCollector { onStreamFinished: schemeQueryProc.running = true } }

    // ════════════════════════════════════════════════════════════════════════
    // Wallpaper: pick one to retheme via the wallust palette (ryoku-shell), the
    // same path the shell's quick strip uses. Instant, no Save.
    // ════════════════════════════════════════════════════════════════════════
    readonly property string wpDir: pg.home + "/Pictures/Wallpapers"
    readonly property string wpState: (Quickshell.env("XDG_STATE_HOME") || (pg.home + "/.local/state")) + "/ryoku-wallpaper"
    property var wallpapers: []
    property string currentWall: ""

    function refreshWalls() { wallListProc.running = true; wallStateProc.running = true; }
    function applyWall(p) {
        pg.currentWall = p;
        wallApplyProc.command = ["ryoku-shell", "wallpaper", "set", p];
        wallApplyProc.running = true;
    }
    Process {
        id: wallListProc
        command: ["sh", "-c", "find \"$1\" -maxdepth 1 -type f \\( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \\) -printf '%T@\\t%p\\n' | sort -rn", "_", pg.wpDir]
        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.split("\n"), out = [];
                for (var i = 0; i < lines.length; i++) {
                    var t = lines[i].indexOf("\t");
                    if (t < 1) continue;
                    var p = lines[i].substring(t + 1);
                    out.push({ "path": p, "name": p.substring(p.lastIndexOf("/") + 1) });
                }
                pg.wallpapers = out;
            }
        }
    }
    Process {
        id: wallStateProc
        command: ["sh", "-c", "cat \"$1\" 2>/dev/null || true", "_", pg.wpState]
        stdout: StdioCollector { onStreamFinished: pg.currentWall = this.text.trim() }
    }
    Process { id: wallApplyProc; stdout: StdioCollector { onStreamFinished: wallStateProc.running = true } }
    Process {
        id: wallNextProc
        command: ["ryoku-shell", "wallpaper", "next"]
        stdout: StdioCollector { onStreamFinished: wallStateProc.running = true }
    }

    // ════════════════════════════════════════════════════════════════════════
    // Comfort: backlight and night light, applied at once via the shipped tools.
    // ════════════════════════════════════════════════════════════════════════
    readonly property string scriptsDir: pg.home + "/.config/hypr/scripts/"
    property int brightness: -1
    property bool nightOn: false
    property int nightTemp: 4000
    property string comfortError: ""

    function refreshComfort() { brightGetProc.running = true; nightStatusProc.running = true; }
    function setBrightness(v) {
        pg.brightness = v;
        brightSetProc.command = ["brightnessctl", "set", v + "%"];
        brightSetProc.running = true;
    }
    function setNight(on) {
        pg.nightOn = on;
        nightProc.command = on ? [pg.scriptsDir + "ryoku-cmd-nightlight", "on", String(pg.nightTemp)]
                               : [pg.scriptsDir + "ryoku-cmd-nightlight", "off"];
        nightProc.running = true;
    }
    function setNightTemp(t) { pg.nightTemp = t; if (pg.nightOn) nightDebounce.restart(); }

    Process {
        id: brightGetProc
        command: ["brightnessctl", "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                var first = this.text.trim().split("\n")[0];
                var pct = parseInt((first.split(",")[3] || "").replace("%", ""), 10);
                if (!isNaN(pct)) pg.brightness = pct;
            }
        }
    }
    Process {
        id: brightSetProc
        onExited: (code, status) => {
            pg.comfortError = code === 0 ? "" : "Couldn't set brightness.";
            if (pg.comfortError !== "") comfortErrorClear.restart();
        }
    }
    Process {
        id: nightStatusProc
        command: [pg.scriptsDir + "ryoku-cmd-nightlight", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim().split(" ");
                pg.nightOn = t[0] === "on";
                if (t.length > 1) {
                    var k = parseInt(t[1], 10);
                    if (!isNaN(k)) pg.nightTemp = k;
                }
            }
        }
    }
    Process {
        id: nightProc
        onExited: (code, status) => {
            pg.comfortError = code === 0 ? "" : "Couldn't change the night light.";
            if (pg.comfortError !== "") comfortErrorClear.restart();
        }
    }
    Timer { id: nightDebounce; interval: 300; onTriggered: if (pg.nightOn) pg.setNight(true) }
    Timer { id: comfortErrorClear; interval: 6000; onTriggered: pg.comfortError = "" }

    // ════════════════════════════════════════════════════════════════════════
    // Rices: whole-desktop looks. Browse My rices / the store, then apply, fork,
    // delete, set a wallpaper, view the config, export. All ryoku-hub rice.
    // ════════════════════════════════════════════════════════════════════════
    property var rices: []
    property var catalog: []
    property bool ricesLoading: true
    property bool browseMode: false
    property bool catalogLoading: false
    property bool catalogError: false
    property string selectedSlug: ""
    property bool capturing: false
    property var touches: []
    property string configText: ""
    property string exportedTo: ""
    // what a save would carry right now (`ryoku-hub rice preflight`), shown
    // in the capture card so coverage is visible before naming, not after.
    property var preflight: null

    readonly property var selectedRice: {
        for (var i = 0; i < pg.rices.length; i++)
            if (pg.rices[i].slug === pg.selectedSlug) return pg.rices[i];
        return null;
    }
    readonly property bool hasActiveRice: {
        for (var i = 0; i < pg.rices.length; i++)
            if (pg.rices[i].active) return true;
        return false;
    }

    onSelectedSlugChanged: {
        pg.exportedTo = "";
        if (pg.selectedSlug !== "" && !pg.browseMode) pg.loadFiles();
    }

    function reloadRices() {
        pg.ricesLoading = true;
        listProc.running = true;
        if (pg.selectedSlug !== "") pg.loadFiles();
    }
    function loadCatalog() {
        pg.catalogLoading = true;
        pg.catalogError = false;
        catalogProc.running = true;
    }
    function showBrowse(on) {
        pg.browseMode = on;
        if (on && pg.catalog.length === 0 && !pg.catalogLoading) pg.loadCatalog();
    }
    function applyRice(slug, layers) {
        applyProc.command = ["ryoku-hub", "rice", "apply", slug].concat(layers || []);
        applyProc.running = true;
    }
    function restoreOriginal() {
        restoreProc.command = ["ryoku-hub", "rice", "restore", "baseline"];
        restoreProc.running = true;
    }
    function capture(name) {
        if (!name) return;
        captureProc.command = ["ryoku-hub", "rice", "capture", name, "all"];
        captureProc.running = true;
    }
    function delRice(slug) { deleteProc.command = ["ryoku-hub", "rice", "delete", slug]; deleteProc.running = true; }
    function forkRice(slug) { forkProc.command = ["ryoku-hub", "rice", "fork", slug]; forkProc.running = true; }
    function installRice(id) { installProc.command = ["ryoku-hub", "rice", "install", id]; installProc.running = true; }
    function setwall(path) {
        if (!path || pg.selectedSlug === "") return;
        setwallProc.command = ["ryoku-hub", "rice", "setwall", pg.selectedSlug, path];
        setwallProc.running = true;
    }
    function loadFiles() {
        if (pg.selectedSlug === "") return;
        pg.touches = [];
        pg.configText = "";
        filesProc.command = ["ryoku-hub", "rice", "files", pg.selectedSlug];
        filesProc.running = true;
    }
    function exportRice(dest) {
        if (!dest || pg.selectedSlug === "") return;
        exportProc.command = ["ryoku-hub", "rice", "export", pg.selectedSlug, dest];
        exportProc.running = true;
    }
    function revealPath(path) { if (path) { revealProc.command = ["xdg-open", path]; revealProc.running = true; } }
    // friendly names for the behaviour bundles a rice can carry.
    function layerLabel(k) {
        var map = {
            "keybinds": "Keybinds", "input": "Input", "windowRules": "Window rules",
            "layerRules": "Layer rules", "appOverrides": "Per-app overrides",
            "autostart": "Autostart", "env": "Environment", "brand": "Brand"
        };
        return map[k] || k;
    }
    // one line of truth for the capture card: what a save carries right now.
    function preflightSummary() {
        var p = pg.preflight;
        if (!p) return "";
        var parts = ["look + widgets + visualiser"];
        if (p.wallpaper) parts.push(p.live ? "live video wallpaper" : "wallpaper");
        if (p.decors > 0) parts.push(p.decors + (p.decors === 1 ? " decor" : " decors"));
        parts.push(p.fixed ? "fixed palette" : "colours follow the wallpaper");
        if (p.layers && p.layers.length > 0) {
            var ls = [];
            for (var i = 0; i < p.layers.length; i++) ls.push(pg.layerLabel(p.layers[i]).toLowerCase());
            parts.push("layers: " + ls.join(", "));
        }
        return "Saves  " + parts.join("  \u00b7  ");
    }
    function importRiceFolder(path) {
        if (!path) return;
        importProc.command = ["ryoku-hub", "rice", "import", path];
        importProc.running = true;
    }

    Process {
        id: listProc
        command: ["ryoku-hub", "rice", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.rices = JSON.parse(this.text) || []; } catch (e) { pg.rices = []; }
                pg.ricesLoading = false;
            }
        }
    }
    Process {
        id: catalogProc
        command: ["ryoku-hub", "rice", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.catalog = JSON.parse(this.text) || []; pg.catalogError = false; }
                catch (e) { pg.catalog = []; pg.catalogError = true; }
                pg.catalogLoading = false;
            }
        }
    }
    Process { id: applyProc; onExited: (code, status) => { pg.selectedSlug = ""; pg.reloadRices(); } }
    Process { id: restoreProc; onExited: (code, status) => pg.reloadRices() }
    Process { id: captureProc; onExited: (code, status) => { pg.capturing = false; pg.reloadRices(); } }
    Process { id: importProc; onExited: (code, status) => pg.reloadRices() }
    Process {
        id: preflightProc
        command: ["ryoku-hub", "rice", "preflight"]
        stdout: StdioCollector {
            onStreamFinished: { try { pg.preflight = JSON.parse(this.text); } catch (e) { pg.preflight = null; } }
        }
    }
    Process { id: deleteProc; onExited: (code, status) => { pg.selectedSlug = ""; pg.reloadRices(); } }
    Process { id: forkProc; onExited: (code, status) => { pg.selectedSlug = ""; pg.reloadRices(); } }
    Process { id: installProc; onExited: (code, status) => { pg.reloadRices(); pg.loadCatalog(); } }
    Process { id: setwallProc; onExited: (code, status) => pg.reloadRices() }
    Process {
        id: filesProc
        stdout: StdioCollector {
            onStreamFinished: {
                try { var d = JSON.parse(this.text) || {}; pg.touches = d.touches || []; pg.configText = d.config || ""; }
                catch (e) { pg.touches = []; pg.configText = ""; }
            }
        }
    }
    Process {
        id: exportProc
        stdout: StdioCollector {
            onStreamFinished: { try { pg.exportedTo = (JSON.parse(this.text) || {}).path || ""; } catch (e) { pg.exportedTo = ""; } }
        }
    }
    Process { id: revealProc }

    // lazy refresh, matching the old page's onGroupChanged wiring.
    onTabChanged: {
        if (pg.tab === "Theme") { pg.refreshWalls(); schemeQueryProc.running = true; themeAppsQueryProc.running = true; }
        else if (pg.tab === "Comfort") pg.refreshComfort();
        else if (pg.tab === "Borders") schemeQueryProc.running = true;
        else if (pg.tab === "Rices") pg.reloadRices();
    }
    Component.onCompleted: { pg.refreshWalls(); pg.refreshComfort(); pg.reloadRices(); }

    // ════════════════════════════════════════════════════════════════════════
    // small shared pieces
    // ════════════════════════════════════════════════════════════════════════

    // a section header: dot + tracked caps title + a soft leader eating the gap.
    component SectionHead: Item {
        id: sh
        property string title: ""
        implicitHeight: 20
        Row {
            id: shLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s2
            Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
            Text {
                text: sh.title
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fMicro
                font.weight: Font.Medium
                font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Rectangle {
            anchors.left: shLabel.right
            anchors.right: parent.right
            anchors.leftMargin: Tokens.s3
            anchors.verticalCenter: parent.verticalCenter
            height: 1
            color: Tokens.lineSoft
        }
    }

    // a rice as a storefront tile: monochrome chrome around a colour preview
    // (the look is the data the user is choosing), name, blurb, compat tags.
    component RiceCard: Rectangle {
        id: card
        property var rice: ({})
        property bool store: false
        signal opened()

        readonly property string preview: card.rice.preview || card.rice.posterUrl || ""
        readonly property bool active: !!card.rice.active
        readonly property bool installed: !!card.rice.installed
        readonly property string compat: card.rice.compat || "unknown"

        implicitHeight: 250
        radius: Tokens.radius
        color: hov.hovered ? Tokens.tint5 : "transparent"
        border.width: card.active ? 2 : Tokens.border
        border.color: card.active ? Tokens.ink : (hov.hovered ? Tokens.lineStrong : Tokens.line)
        clip: true
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

        Item {
            id: shot
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 148
            clip: true

            // monochrome window silhouette when the rice ships no image yet.
            Rectangle {
                anchors.fill: parent
                anchors.margins: Tokens.s2
                visible: card.preview === ""
                color: "transparent"
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 0.6
                    height: parent.height * 0.6
                    radius: Tokens.radius
                    color: "transparent"
                    border.width: Tokens.border
                    border.color: Tokens.line
                    Row {
                        anchors { top: parent.top; left: parent.left; margins: Tokens.s2 }
                        spacing: Tokens.s1
                        Rectangle { width: 5; height: 5; radius: 2.5; color: Tokens.inkFaint }
                        Rectangle { width: 5; height: 5; radius: 2.5; color: Tokens.inkFaint }
                        Rectangle { width: 5; height: 5; radius: 2.5; color: Tokens.inkFaint }
                    }
                }
            }
            // the preview screenshot, in colour: a specimen of the look.
            Image {
                anchors.fill: parent
                visible: card.preview !== ""
                source: card.preview
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 720
            }

            // ACTIVE / INSTALLED marker as a file-truth tag, no colour.
            Row {
                anchors { top: parent.top; right: parent.right; margins: Tokens.s3 }
                spacing: Tokens.s1
                visible: card.active || (card.store && card.installed)
                Rectangle {
                    visible: card.active
                    width: 6; height: 6; radius: 3
                    color: Tokens.ink
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: card.active ? I18n.tr("ACTIVE") : I18n.tr("INSTALLED")
                    color: card.active ? Tokens.ink : Tokens.inkMuted
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                }
            }

            // a live (video) wall: the tile shows its tuned frame, the badge
            // says it moves.
            Rectangle {
                visible: !!card.rice.live
                anchors { left: parent.left; bottom: parent.bottom; margins: Tokens.s3 }
                width: liveTag.implicitWidth + Tokens.s2 * 2
                height: 16
                radius: Tokens.radius
                color: Tokens.paper
                border.width: Tokens.border
                border.color: Tokens.lineStrong
                Text {
                    id: liveTag
                    anchors.centerIn: parent
                    text: I18n.tr("LIVE")
                    color: Tokens.ink
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                    font.letterSpacing: Tokens.trackLabel
                }
            }
        }

        Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.top: shot.bottom; height: 1; color: Tokens.lineSoft }

        Column {
            anchors { left: parent.left; right: parent.right; top: shot.bottom; margins: Tokens.s3 }
            anchors.topMargin: Tokens.s3
            spacing: Tokens.s2

            Text {
                width: parent.width
                text: card.rice.name || card.rice.slug || ""
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fRow
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: card.rice.blurb || "A saved desktop look."
                color: Tokens.inkMuted
                font.family: Tokens.ui
                font.pixelSize: Tokens.fSmall
                lineHeight: 1.3
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Row {
                spacing: Tokens.s2
                Text {
                    visible: card.compat === "older" || card.compat === "newer"
                    text: card.compat === "older" ? I18n.tr("OLDER RYOKU") : I18n.tr("NEWER RYOKU")
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                }
                Text {
                    visible: (card.rice.createdWith || "") !== ""
                    text: "v" + (card.rice.createdWith || "")
                    color: Tokens.inkFaint
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fTiny
                }
            }
        }

        HoverHandler { id: hov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: card.opened() }
    }

    // the loading state. the motion contract permits exactly one perpetual
    // animation (the dirty heartbeat), so a wait reads as a static tracked word,
    // not a spinner; it swaps out the moment data lands.
    component Tick: Text {
        text: I18n.tr("LOADING")
        color: Tokens.inkMuted
        font.family: Tokens.ui
        font.pixelSize: Tokens.fMicro
        font.weight: Font.Medium
        font.letterSpacing: Tokens.trackMark
    }

    // the settings sheet, inline. SettingsSheet is not exposed through the
    // parent-directory import in this host, so the shared renderer is
    // reproduced from the same Ryoku.Ui primitives (Section, Cell, and the
    // Sw/Step/Slid/Seg/PickBar controls), with a colour-swatch control the
    // schema needs and the cursor catalogue routed to this page's own picker.
    // It reads the draft and reports edits; it writes nothing.
    component Sheet: Flickable {
        id: sheet
        property var schema: []
        property var draft: null
        property var defaults: ({})
        property string tab: ""
        property string query: ""
        signal edited(string key, var value)
        signal pickRequested(var row)

        readonly property var rows: {
            var q = sheet.query.toLowerCase();
            return sheet.schema.filter(function (r) {
                if (r.tab !== sheet.tab && sheet.query === "") return false;
                if (sheet.query === "") return true;
                return (r.label + " " + (r.desc || "") + " " + r.key).toLowerCase().indexOf(q) >= 0;
            });
        }
        readonly property var groups: {
            var g = [];
            for (var i = 0; i < sheet.rows.length; i++)
                if (g.indexOf(sheet.rows[i].group) < 0) g.push(sheet.rows[i].group);
            return g;
        }
        function val(r) { if (!sheet.draft) return ""; var v = sheet.draft[r.key]; return v === undefined ? "" : v; }
        function shown(r) {
            var v = sheet.val(r);
            if (r.ctl === "sw") return v ? "ON" : "OFF";
            if (r.ctl === "slid" && r.pct) return String(Math.round(v * 100));
            if (r.ctl === "color") return String(v).toUpperCase();
            return String(v);
        }
        function shownDef(r) {
            var d = sheet.defaults[r.key];
            if (d === undefined) return "";
            if (r.ctl === "sw") return d ? "ON" : "OFF";
            if (r.ctl === "slid" && r.pct) return String(Math.round(d * 100));
            return String(d);
        }
        function isChanged(r) {
            var v = sheet.val(r), d = sheet.defaults[r.key];
            if (d === undefined) return false;
            return v !== d;
        }
        function reserve(ctl, opts, w) {
            if (ctl === "color") return 150;
            if (ctl === "text") return 180;
            return Spans.inlineWidth(ctl, opts, w);
        }

        contentWidth: width
        contentHeight: col.height + Tokens.s5
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

        Column {
            id: col
            width: sheet.width - Tokens.s3
            spacing: Tokens.s5

            Repeater {
                model: sheet.groups
                Section {
                    id: sect
                    required property string modelData
                    width: col.width
                    title: modelData === "" ? I18n.tr("OTHER") : modelData

                    // bento: flush rows, no ragged right edge (same packer as
                    // the shared sheet).
                    readonly property var groupRows: sheet.rows.filter(function (r) { return r.group === sect.modelData; })
                    readonly property int minSpan: {
                        for (var n = 1; n <= Spans.cols; n++)
                            if (n * colWidth + (n - 1) * gutter >= 290) return n;
                        return Spans.cols;
                    }
                    readonly property var packed: Spans.pack(
                        groupRows.map(function (r) { return (r.ctl === "layoutdemo" || (r.ctl === "seg" && (r.opts || []).length >= 3)) ? Spans.cols : Spans.of(r.ctl, (r.opts || []).length); }),
                        minSpan)

                    Repeater {
                        model: sect.groupRows
                        Cell {
                            id: cell
                            required property var modelData
                            required property int index
                            readonly property var r: modelData
                            readonly property int optCount: (r.opts || []).length
                            readonly property bool foot: r.ctl === "pick"

                            width: sect.span(sect.packed[index] || 4)
                            height: neededHeight
                            block: cell.foot || Spans.isBlock(r.ctl) || r.ctl === "layoutdemo" || (r.ctl === "seg" && cell.optCount >= 3)
                            controlWidth: sheet.reserve(r.ctl, optCount, width)

                            label: I18n.tr(r.label)
                            desc: r.desc || ""
                            unit: r.pct ? "%" : (r.unit || "")
                            value: sheet.shown(r)
                            def: sheet.shownDef(r)
                            changed: sheet.isChanged(r)
                            source: "hypr.json"

                            Loader {
                                anchors.fill: parent
                                sourceComponent: {
                                    switch (cell.r.ctl) {
                                    case "sw": return swC;
                                    case "step": return stepC;
                                    case "slid": return slidC;
                                    case "seg": return segC;
                                    case "pick": return pickC;
                                    case "color": return colorC;
                                    case "layoutdemo": return demoC;
                                    default: return textC;
                                    }
                                }
                            }
                            Component {
                                id: swC
                                Sw {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    on: !!sheet.val(cell.r); onToggled: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            Component {
                                id: stepC
                                Step {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    value: Number(sheet.val(cell.r)) || 0
                                    from: Number(cell.r.lo) || 0; to: Number(cell.r.hi) || 100
                                    onModified: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            Component {
                                id: slidC
                                Slid {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    width: Math.round(cell.width * 0.42)
                                    value: Number(sheet.val(cell.r)) || 0
                                    from: Number(cell.r.lo) || 0; to: Number(cell.r.hi) || 1
                                    onModified: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            Component {
                                id: segC
                                Seg {
                                    anchors.right: cell.block ? undefined : parent.right; anchors.left: cell.block ? parent.left : undefined; anchors.verticalCenter: parent.verticalCenter
                                    options: cell.r.opts; current: String(sheet.val(cell.r))
                                    onChose: (k) => sheet.edited(cell.r.key, k)
                                }
                            }
                            Component {
                                id: pickC
                                PickBar {
                                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                                    value: String(sheet.val(cell.r)); count: cell.optCount
                                    onOpened: sheet.pickRequested(cell.r)
                                }
                            }
                            Component {
                                id: colorC
                                Row {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    spacing: Tokens.s2
                                    Rectangle {
                                        width: 24; height: 24; radius: Tokens.radius
                                        anchors.verticalCenter: parent.verticalCenter
                                        // a swatch is a colour specimen (data), the one sanctioned chroma.
                                        color: /^#?[0-9A-Fa-f]{6}$/.test(String(sheet.val(cell.r))) ? String(sheet.val(cell.r)) : "transparent"
                                        border.width: Tokens.border; border.color: Tokens.line
                                    }
                                    Field {
                                        width: 96; tabular: true
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: String(sheet.val(cell.r))
                                        onCommitted: (v) => sheet.edited(cell.r.key, v)
                                    }
                                }
                            }
                            Component {
                                id: textC
                                Field {
                                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                    width: 176; tabular: true
                                    text: String(sheet.val(cell.r))
                                    onCommitted: (v) => sheet.edited(cell.r.key, v)
                                }
                            }
                            // the tiling-layout preview: a looping diagram of the
                            // drafted layout (dwindle / master / scrolling), swapped
                            // live as the picker above changes. gifs ship in ../art.
                            Component {
                                id: demoC
                                Item {
                                    id: demo
                                    implicitHeight: 200
                                    readonly property string layout: {
                                        var v = sheet.draft ? sheet.draft["appearance.layout"] : "";
                                        return (v === "master" || v === "scrolling") ? v : "dwindle";
                                    }
                                    readonly property var blurbs: ({
                                        "dwindle": "Each new window splits the focused frame in two, so the layout spirals into smaller and smaller frames.",
                                        "master": "One big master frame keeps the focus; every other window stacks down the side beside it.",
                                        "scrolling": "Windows line up in one endless horizontal row; the strip pans sideways to keep the focused column in view."
                                    })
                                    Rectangle {
                                        id: screen
                                        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                                        width: Math.min(380, demo.width * 0.52)
                                        color: "transparent"
                                        radius: Tokens.radius
                                        border.width: Tokens.border
                                        border.color: Tokens.line
                                        AnimatedImage {
                                            anchors.fill: parent
                                            anchors.margins: Tokens.s3
                                            source: Qt.resolvedUrl("../art/tiling-" + demo.layout + ".gif")
                                            fillMode: Image.PreserveAspectFit
                                            playing: true
                                            cache: false
                                            asynchronous: true
                                            onStatusChanged: if (status === Image.Ready) playing = true
                                        }
                                    }
                                    Column {
                                        anchors { left: screen.right; leftMargin: Tokens.s5; right: parent.right; verticalCenter: screen.verticalCenter }
                                        spacing: Tokens.s2
                                        Text {
                                            text: demo.layout.toUpperCase()
                                            color: Tokens.ink
                                            font.family: Tokens.display; font.pixelSize: Tokens.fValue
                                        }
                                        Text {
                                            width: parent.width
                                            text: demo.blurbs[demo.layout] || ""
                                            color: Tokens.inkMuted
                                            font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        Column {
            anchors.centerIn: parent
            visible: sheet.rows.length === 0
            spacing: Tokens.s2
            Text {
                text: I18n.tr("NO MATCH"); color: Tokens.inkDim; font.family: Tokens.ui
                font.pixelSize: Tokens.fRow; font.letterSpacing: 2
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Text {
                text: I18n.tr("nothing here matches: ") + sheet.query
                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // head: eyebrow, Fraunces title, blurb (matches every settings page)
    // ════════════════════════════════════════════════════════════════════════
    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        spacing: Tokens.s2

        Item {
            width: parent.width
            height: 14
            Row {
                id: ebrow
                spacing: Tokens.s2
                anchors.verticalCenter: parent.verticalCenter
                Rectangle { width: 16; height: 1; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                Text {
                    text: "力"; color: Tokens.ink; font.family: Tokens.jp
                    font.pixelSize: Tokens.fMicro; anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    text: pg.pEyebrow; color: Tokens.inkMuted; font.family: Tokens.ui
                    font.pixelSize: Tokens.fTiny; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
            // the band runs to the page edge and closes with the sheet's marks:
            // a register cross and the /// cluster, matching every settings page.
            Rectangle {
                anchors { left: ebrow.right; right: crossMark.left; verticalCenter: parent.verticalCenter }
                anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3
                height: 1; color: Tokens.lineSoft
            }
            Text {
                id: crossMark
                anchors { right: slashMark.left; rightMargin: Tokens.s2; verticalCenter: parent.verticalCenter }
                text: "+"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
            }
            Text {
                id: slashMark
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: "///"; color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
            }
        }
        Text {
            text: pg.pTitle; color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: pg.pBlurb
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
        Item { width: 1; height: Tokens.s1 }

        // tab bar only: the "edits show live" note was redundant with the state
        // card and ran under the side column, so it is gone.
        Tabs {
            options: pg.tabs
            current: pg.tab
            onChose: (label) => pg.tab = label
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // content region: one sheet for the draft tabs, bespoke views for the rest
    // ════════════════════════════════════════════════════════════════════════
    Item {
        id: content
        anchors { left: parent.left; right: parent.right; top: head.bottom; bottom: parent.bottom; topMargin: Tokens.s5 }

        // ── Look / Borders / Cursor: the live Hyprland draft ──
        Sheet {
            id: sheet
            anchors.fill: parent
            visible: pg.settingsTab || pg.searching
            schema: pg.settingsSchema
            draft: pg.draft
            defaults: pg.committed
            tab: pg.settingsTab ? pg.tab : "Windows"
            query: pg.hub ? (pg.hub.query || "") : ""
            onEdited: (k, v) => pg.setKey(k, v)
            onPickRequested: (r) => {
                if (r.key === "cursor.theme") cursorPick.show();
                else if (pg.hub) pg.hub.openPick(r);
            }
        }

        // ── Wallpaper: theme scheme + the wallpaper gallery ──
        Flickable {
            id: wallView
            anchors.fill: parent
            visible: pg.tab === "Theme" && !pg.searching
            contentWidth: width
            contentHeight: wallCol.height + Tokens.s5
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            Column {
                id: wallCol
                width: wallView.width - Tokens.s3
                spacing: Tokens.s5

                Column {
                    visible: pg.tab === "Theme"
                    width: parent.width
                    spacing: Tokens.s3
                    SectionHead { width: parent.width; title: I18n.tr("THEME PALETTE") }
                    Row {
                        spacing: Tokens.s3
                        Column {
                            spacing: Tokens.s1
                            Text {
                                text: I18n.tr("COLOURS")
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Tokens.trackLabel
                            }
                            Text {
                                text: pg.scheme === "custom" ? I18n.tr("Custom") : (pg.scheme.charAt(0).toUpperCase() + pg.scheme.slice(1))
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fValue
                                font.weight: Font.Light
                            }
                        }
                        Seg {
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["FOLLOW", "LIGHT", "DARK"]
                            current: pg.scheme.toUpperCase()
                            onChose: (k) => pg.setScheme(k.toLowerCase())
                        }
                    }
                    Text {
                        width: Math.min(parent.width, 620)
                        wrapMode: Text.WordWrap
                        text: pg.scheme === "light" || pg.scheme === "dark"
                            ? I18n.tr("A fixed ") + pg.scheme + I18n.tr(" palette, kept across wallpaper changes.")
                            : pg.scheme === "custom"
                              ? I18n.tr("A fixed palette is set. Pick Follow, Light, or Dark to change it.")
                              : I18n.tr("Colours are derived from your wallpaper and update when it changes.")
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                    }
                    Row {
                        width: parent.width
                        spacing: Tokens.s3
                        topPadding: Tokens.s2
                        Column {
                            width: Math.max(0, parent.width - appsSw.width - Tokens.s3)
                            spacing: Tokens.s1
                            Text {
                                text: I18n.tr("THEME APPS")
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fMicro
                                font.weight: Font.Medium
                                font.letterSpacing: Tokens.trackLabel
                            }
                            Text {
                                width: parent.width
                                wrapMode: Text.WordWrap
                                text: I18n.tr("Extend the palette past the shell into GTK and GUI apps, so Files, text editors, and other desktop apps recolour to match. Off keeps them stock.")
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall
                            }
                        }
                        Sw {
                            id: appsSw
                            anchors.verticalCenter: parent.verticalCenter
                            on: pg.themeApps
                            onToggled: (v) => pg.setThemeApps(v)
                        }
                    }
                }

                // Border colours: the fixed frame colours, sitting right under
                // the scheme that decides whether they apply. Shown only when a
                // fixed palette is set (Follow derives borders from the wallpaper),
                // so the whole "what colour are my borders" question lives here,
                // not split between this scheme and a separate Borders tab.
                Column {
                    visible: pg.tab === "Theme" && pg.scheme !== "follow"
                    width: parent.width
                    spacing: Tokens.s3
                    SectionHead { width: parent.width; title: I18n.tr("BORDER COLOURS") }
                    Text {
                        width: Math.min(parent.width, 620)
                        wrapMode: Text.WordWrap
                        text: I18n.tr("The window frame colours a fixed palette uses; Follow takes the wallpaper's accent instead. Click a swatch to pick, or type a hex.")
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                    }
                    Row {
                        width: parent.width
                        spacing: Tokens.s4
                        Column {
                            width: (parent.width - Tokens.s4) / 2
                            spacing: Tokens.s1
                            Text {
                                text: I18n.tr("ACTIVE WINDOW")
                                color: Tokens.inkMuted; font.family: Tokens.ui
                                font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                                font.letterSpacing: Tokens.trackLabel
                            }
                            ColorField {
                                width: parent.width
                                value: pg.hub ? String(pg.hub.hyprVal("appearance.activeBorder") || "") : ""
                                onChosen: (v) => pg.setKey("appearance.activeBorder", v)
                            }
                        }
                        Column {
                            width: (parent.width - Tokens.s4) / 2
                            spacing: Tokens.s1
                            Text {
                                text: I18n.tr("INACTIVE WINDOW")
                                color: Tokens.inkMuted; font.family: Tokens.ui
                                font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                                font.letterSpacing: Tokens.trackLabel
                            }
                            ColorField {
                                width: parent.width
                                value: pg.hub ? String(pg.hub.hyprVal("appearance.inactiveBorder") || "") : ""
                                onChosen: (v) => pg.setKey("appearance.inactiveBorder", v)
                            }
                        }
                    }
                }

                Column {
                    visible: pg.tab === "Theme"
                    width: parent.width
                    spacing: Tokens.s3
                    SectionHead { width: parent.width; title: I18n.tr("RYOKU DEFAULT") }
                    Row {
                        width: parent.width
                        spacing: Tokens.s3
                        Text {
                            width: Math.max(0, parent.width - ryokuBtn.width - Tokens.s3)
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.WordWrap
                            text: I18n.tr("Reset the whole desktop to the Ryoku signature: the stele bar, square corners, Space Grotesk, and the grainy mono palette.")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                        }
                        Btn {
                            id: ryokuBtn
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("APPLY RYOKU THEME")
                            primary: true
                            onAct: pg.applyRyokuTheme()
                        }
                    }
                }

                Column {
                    visible: pg.tab === "Theme"
                    width: parent.width
                    spacing: Tokens.s3
                    SectionHead { width: parent.width; title: I18n.tr("WALLPAPER") }
                    Row {
                        width: parent.width
                        spacing: Tokens.s3
                        Text {
                            width: Math.max(0, parent.width - shuffleBtn.width - Tokens.s3)
                            anchors.verticalCenter: parent.verticalCenter
                            wrapMode: Text.WordWrap
                            text: I18n.tr("Pick a wallpaper to retheme the desktop. The palette (borders, accents) follows it.")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                        }
                        Btn {
                            id: shuffleBtn
                            anchors.verticalCenter: parent.verticalCenter
                            text: I18n.tr("SHUFFLE")
                            onAct: wallNextProc.running = true
                        }
                    }
                    Flow {
                        width: parent.width
                        spacing: Tokens.s3
                        Repeater {
                            model: pg.wallpapers
                            delegate: Rectangle {
                                id: wp
                                required property var modelData
                                readonly property bool active: pg.currentWall === wp.modelData.path
                                width: 172; height: 104
                                radius: Tokens.radius
                                color: "transparent"
                                border.width: wp.active ? 2 : Tokens.border
                                border.color: wp.active ? Tokens.ink : (wpHov.hovered ? Tokens.lineStrong : Tokens.line)
                                clip: true
                                scale: wpHov.hovered ? 1.02 : 1
                                Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
                                Behavior on scale { NumberAnimation { duration: Tokens.snap; easing.type: Tokens.easeSnap } }
                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 2
                                    source: "file://" + wp.modelData.path
                                    fillMode: Image.PreserveAspectCrop
                                    sourceSize.width: 360
                                    sourceSize.height: 220
                                    asynchronous: true
                                    cache: false
                                }
                                Rectangle {
                                    visible: wp.active
                                    anchors { top: parent.top; right: parent.right; margins: Tokens.s1 }
                                    width: 8; height: 8; radius: 4; color: Tokens.ink
                                }
                                HoverHandler { id: wpHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: pg.applyWall(wp.modelData.path) }
                            }
                        }
                    }
                    Text {
                        visible: pg.wallpapers.length === 0
                        text: I18n.tr("No wallpapers in ~/Pictures/Wallpapers.")
                        color: Tokens.inkFaint
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                    }
                }
            }
        }

        // ── Comfort: backlight + night light ──
        Flickable {
            id: comfortView
            anchors.fill: parent
            visible: pg.tab === "Comfort" && !pg.searching
            contentWidth: width
            contentHeight: comfortCol.height + Tokens.s5
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            Column {
                id: comfortCol
                width: comfortView.width - Tokens.s3
                spacing: Tokens.s5

                Section {
                    id: backSect
                    width: parent.width
                    title: I18n.tr("BACKLIGHT")
                    Cell {
                        width: backSect.span(6)
                        controlWidth: Math.round(width * 0.42)
                        label: I18n.tr("Brightness"); unit: "%"
                        value: String(pg.brightness < 0 ? 100 : pg.brightness)
                        desc: I18n.tr("Hardware backlight, applied at once, floors at 5% to stay visible.")
                        source: ""
                        changed: false
                        Slid {
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                            from: 5; to: 100
                            value: pg.brightness < 0 ? 100 : pg.brightness
                            onModified: (v) => pg.setBrightness(v)
                        }
                    }
                }

                Section {
                    id: nightSect
                    width: parent.width
                    title: I18n.tr("NIGHT LIGHT")
                    Cell {
                        width: nightSect.span(4)
                        controlWidth: 54
                        label: I18n.tr("Warm the screen")
                        value: pg.nightOn ? "ON" : "OFF"
                        desc: I18n.tr("Cuts blue light for the evening, stays on across sessions.")
                        source: ""
                        changed: false
                        Sw {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            on: pg.nightOn
                            onToggled: (v) => pg.setNight(v)
                        }
                    }
                    Cell {
                        width: nightSect.span(6)
                        controlWidth: Math.round(width * 0.42)
                        label: I18n.tr("Temperature"); unit: "K"
                        value: String(pg.nightTemp)
                        desc: I18n.tr("Lower Kelvin is warmer, saved only while the light is on.")
                        source: ""
                        changed: false
                        Slid {
                            width: parent.width
                            anchors.verticalCenter: parent.verticalCenter
                            from: 2500; to: 6500
                            value: pg.nightTemp
                            onModified: (v) => pg.setNightTemp(v)
                        }
                    }
                }

                Text {
                    visible: pg.comfortError !== ""
                    width: Math.min(parent.width, 620)
                    wrapMode: Text.WordWrap
                    text: pg.comfortError
                    color: Tokens.ink
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall
                }
            }
        }

        // ── Rices: browse the grid, then the drill-in detail ──
        Flickable {
            id: ricesView
            anchors.fill: parent
            visible: pg.tab === "Rices" && !pg.searching
            contentWidth: width
            contentHeight: ricesCol.height + Tokens.s5
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

            Column {
                id: ricesCol
                width: ricesView.width - Tokens.s3
                spacing: Tokens.s4

                // ---- the grid (My rices / Browse) ----
                Column {
                    width: parent.width
                    visible: pg.selectedSlug === ""
                    spacing: Tokens.s4

                    Seg {
                        options: ["MY RICES", "BROWSE"]
                        current: pg.browseMode ? "BROWSE" : "MY RICES"
                        onChose: (k) => pg.showBrowse(k === "BROWSE")
                    }

                    // My rices
                    Column {
                        width: parent.width
                        visible: !pg.browseMode
                        spacing: Tokens.s4

                        Row {
                            spacing: Tokens.s3
                            Btn { text: I18n.tr("SAVE CURRENT SETUP"); primary: true; armed: !pg.capturing; onAct: { pg.capturing = true; preflightProc.running = true; } }
                            Btn { text: I18n.tr("IMPORT"); onAct: riceImportPicker.open() }
                            Btn { text: I18n.tr("RESTORE ORIGINAL"); armed: pg.hasActiveRice; onAct: pg.restoreOriginal() }
                        }

                        Rectangle {
                            visible: pg.capturing
                            width: parent.width
                            height: Tokens.rowH
                            radius: Tokens.radius
                            color: "transparent"
                            border.width: Tokens.border
                            border.color: Tokens.line
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: Tokens.s3
                                anchors.rightMargin: Tokens.s2
                                spacing: Tokens.s2
                                Field {
                                    id: nameField
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.max(0, parent.width - saveNow.width - cancelNow.width - Tokens.s2 * 2)
                                    placeholder: I18n.tr("Name this rice (for example, My Setup)")
                                    onCommitted: (v) => pg.capture(v)
                                }
                                Btn {
                                    id: saveNow
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr("SAVE"); primary: true
                                    onAct: pg.capture(nameField.text)
                                }
                                Btn {
                                    id: cancelNow
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: I18n.tr("CANCEL")
                                    onAct: { pg.capturing = false; nameField.clear(); }
                                }
                            }
                        }

                        // the coverage the save will carry, read from a
                        // preflight: everything travels, and the card says so
                        // before the rice is named.
                        Text {
                            visible: pg.capturing && pg.preflight !== null
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: pg.preflightSummary()
                            color: Tokens.inkDim
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fTiny
                            lineHeight: 1.4
                        }

                        Text {
                            visible: !pg.capturing
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: I18n.tr("Save your whole desktop look, windows, bar, colours, wallpaper, and cursor, as a rice. Switch between looks anytime, and restore your original in one click.")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                        }

                        Tick {
                            visible: pg.ricesLoading
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Column {
                            visible: !pg.ricesLoading && pg.rices.length === 0 && !pg.capturing
                            width: parent.width
                            spacing: Tokens.s2
                            topPadding: Tokens.s5
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("No rices yet")
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fRow
                            }
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: I18n.tr("Tune your desktop the way you like, then Save current setup to make your first rice, or Browse the store for one to install.")
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall
                                wrapMode: Text.WordWrap
                            }
                        }

                        Flow {
                            id: mineGrid
                            width: parent.width
                            visible: !pg.ricesLoading && pg.rices.length > 0
                            spacing: Tokens.s3
                            Repeater {
                                model: pg.rices
                                delegate: RiceCard {
                                    required property var modelData
                                    width: Math.max(280, (mineGrid.width - Tokens.s3 * 2) / 3)
                                    rice: modelData
                                    onOpened: pg.selectedSlug = modelData.slug
                                }
                            }
                        }
                    }

                    // Browse the community store
                    Column {
                        width: parent.width
                        visible: pg.browseMode
                        spacing: Tokens.s4

                        Text {
                            width: parent.width
                            wrapMode: Text.WordWrap
                            text: I18n.tr("Install a rice from the community store, then apply it from My rices. A rice built for a different Ryoku version still applies; it is reconciled to yours.")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall
                        }

                        Tick {
                            visible: pg.catalogLoading
                            anchors.horizontalCenter: parent.horizontalCenter
                        }

                        Column {
                            visible: !pg.catalogLoading && pg.catalog.length === 0
                            width: parent.width
                            spacing: Tokens.s3
                            topPadding: Tokens.s5
                            Text {
                                width: parent.width
                                horizontalAlignment: Text.AlignHCenter
                                text: pg.catalogError ? I18n.tr("Couldn't reach the rice store.") : I18n.tr("No rices in the store yet.")
                                color: Tokens.inkMuted
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fSmall
                                wrapMode: Text.WordWrap
                            }
                            Btn {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: I18n.tr("TRY AGAIN")
                                onAct: pg.loadCatalog()
                            }
                        }

                        Flow {
                            id: storeGrid
                            width: parent.width
                            visible: !pg.catalogLoading && pg.catalog.length > 0
                            spacing: Tokens.s3
                            Repeater {
                                model: pg.catalog
                                delegate: RiceCard {
                                    required property var modelData
                                    width: Math.max(280, (storeGrid.width - Tokens.s3 * 2) / 3)
                                    rice: modelData
                                    store: true
                                    onOpened: {
                                        if (modelData.installed) { pg.browseMode = false; pg.selectedSlug = modelData.id; }
                                        else pg.installRice(modelData.id);
                                    }
                                }
                            }
                        }
                    }
                }

                // ---- the detail drill-in ----
                Column {
                    id: detailCol
                    width: parent.width
                    visible: pg.selectedSlug !== "" && pg.selectedRice !== null
                    spacing: Tokens.s4

                    readonly property var rice: pg.selectedRice || ({})
                    readonly property var layerKeys: detailCol.rice.layers ? Object.keys(detailCol.rice.layers) : []
                    readonly property string preview: detailCol.rice.preview || ""

                    // behaviour toggles: every bundled layer applies by
                    // default; tapping a chip excludes it (KDE's global-theme
                    // partial apply, as chips). reset when another rice opens.
                    property var layerOff: ({})
                    onLayerKeysChanged: detailCol.layerOff = ({})
                    function chosenLayers() {
                        var out = [];
                        for (var i = 0; i < detailCol.layerKeys.length; i++)
                            if (!detailCol.layerOff[detailCol.layerKeys[i]])
                                out.push(detailCol.layerKeys[i]);
                        return out;
                    }

                    function changeSummary() {
                        var parts = [];
                        var look = detailCol.rice.look || ({});
                        if (look.hypr && Object.keys(look.hypr).length > 0) parts.push("windows");
                        if (look.shell && Object.keys(look.shell).length > 0) parts.push("shell + bar");
                        if (look.widgets && Object.keys(look.widgets).length > 0) parts.push("widgets");
                        if (look.visualizer && Object.keys(look.visualizer).length > 0) parts.push("visualiser");
                        if (look.decor && Object.keys(look.decor).length > 0) parts.push("decors");
                        if (detailCol.rice.color) parts.push("colours");
                        var a = detailCol.rice.assets || ({});
                        if (a.wallpaper) parts.push(detailCol.rice.live ? "live wallpaper" : "wallpaper");
                        if (a.cursor) parts.push("cursor");
                        if (a.hero) parts.push("launcher art");
                        return parts.join("  \u00b7  ");
                    }

                    Row {
                        spacing: Tokens.s3
                        IconBtn {
                            id: detailBack
                            anchors.verticalCenter: parent.verticalCenter
                            glyph: "‹"
                            onAct: pg.selectedSlug = ""
                        }
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            width: Math.max(0, detailCol.width - detailBack.width - Tokens.s3)
                            spacing: Tokens.s1
                            Text {
                                width: parent.width
                                text: detailCol.rice.name || detailCol.rice.slug || ""
                                color: Tokens.ink
                                font.family: Tokens.ui
                                font.pixelSize: Tokens.fRow
                                elide: Text.ElideRight
                            }
                            Text {
                                width: parent.width
                                text: I18n.tr("Changes ") + detailCol.changeSummary()
                                color: Tokens.inkFaint
                                font.family: Tokens.mono
                                font.pixelSize: Tokens.fTiny
                                elide: Text.ElideRight
                            }
                        }
                    }

                    Rectangle {
                        width: parent.width
                        height: Math.min(320, parent.width * 0.5)
                        radius: Tokens.radius
                        clip: true
                        color: "transparent"
                        border.width: Tokens.border
                        border.color: Tokens.line
                        // monochrome window silhouette when no preview ships.
                        Rectangle {
                            anchors.centerIn: parent
                            visible: detailCol.preview === ""
                            width: parent.width * 0.5
                            height: parent.height * 0.56
                            radius: Tokens.radius
                            color: "transparent"
                            border.width: Tokens.border
                            border.color: Tokens.lineStrong
                        }
                        Image {
                            anchors.fill: parent
                            anchors.margins: 1
                            visible: detailCol.preview !== ""
                            source: detailCol.preview
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 1200
                        }
                        // the saved wall is a video: the frame above is its
                        // tuned still, the badge says the desktop will move.
                        Rectangle {
                            visible: !!detailCol.rice.live
                            anchors { left: parent.left; bottom: parent.bottom; margins: Tokens.s3 }
                            width: liveDetailTag.implicitWidth + Tokens.s2 * 2
                            height: 18
                            radius: Tokens.radius
                            color: Tokens.paper
                            border.width: Tokens.border
                            border.color: Tokens.lineStrong
                            Text {
                                id: liveDetailTag
                                anchors.centerIn: parent
                                text: I18n.tr("LIVE WALLPAPER")
                                color: Tokens.ink
                                font.family: Tokens.mono
                                font.pixelSize: Tokens.fTiny
                                font.letterSpacing: Tokens.trackLabel
                            }
                        }
                    }

                    Text {
                        visible: (detailCol.rice.blurb || "") !== ""
                        width: parent.width
                        text: detailCol.rice.blurb || ""
                        color: Tokens.inkMuted
                        font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall
                        wrapMode: Text.WordWrap
                        lineHeight: 1.4
                    }

                    // WHAT IT TOUCHES: the config files + assets this rice writes.
                    Column {
                        visible: pg.touches.length > 0
                        width: parent.width
                        spacing: Tokens.s2
                        Text {
                            text: I18n.tr("WHAT IT TOUCHES")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackLabel
                        }
                        Repeater {
                            model: pg.touches
                            delegate: Column {
                                id: trow
                                required property var modelData
                                width: detailCol.width
                                spacing: 1
                                opacity: trow.modelData.provided ? 1 : 0.45
                                Text {
                                    width: parent.width
                                    text: I18n.tr(trow.modelData.label)
                                    color: Tokens.inkDim
                                    font.family: Tokens.ui
                                    font.pixelSize: Tokens.fSmall
                                    font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: trow.modelData.path + (trow.modelData.provided ? "" : I18n.tr("  (unchanged)"))
                                    color: Tokens.inkFaint
                                    font.family: Tokens.mono
                                    font.pixelSize: Tokens.fTiny
                                    elide: Text.ElideMiddle
                                }
                            }
                        }
                    }

                    // ALSO SETS: behaviour the rice carries beyond the look,
                    // as toggles. the look always applies; a chip tapped off
                    // keeps that bundle from touching the recipient's setup.
                    Column {
                        visible: detailCol.layerKeys.length > 0
                        width: parent.width
                        spacing: Tokens.s2
                        Text {
                            text: I18n.tr("ALSO SETS \u00b7 TAP TO EXCLUDE")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackLabel
                        }
                        Flow {
                            width: parent.width
                            spacing: Tokens.s2
                            Repeater {
                                model: detailCol.layerKeys
                                delegate: Rectangle {
                                    id: lchip
                                    required property string modelData
                                    readonly property bool on: !detailCol.layerOff[lchip.modelData]
                                    width: lchipText.implicitWidth + Tokens.s3 * 2
                                    height: 22
                                    radius: Tokens.radius
                                    color: lchip.on ? Tokens.tint10 : "transparent"
                                    border.width: Tokens.border
                                    border.color: lchip.on ? Tokens.lineStrong : Tokens.line
                                    Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                    Text {
                                        id: lchipText
                                        anchors.centerIn: parent
                                        text: pg.layerLabel(lchip.modelData)
                                        color: lchip.on ? Tokens.ink : Tokens.inkFaint
                                        font.family: Tokens.ui
                                        font.pixelSize: Tokens.fSmall
                                        font.strikeout: !lchip.on
                                    }
                                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    TapHandler {
                                        onTapped: {
                                            var m = Object.assign({}, detailCol.layerOff);
                                            m[lchip.modelData] = !m[lchip.modelData];
                                            detailCol.layerOff = m;
                                        }
                                    }
                                }
                            }
                        }
                    }

                    Flow {
                        width: parent.width
                        spacing: Tokens.s3
                        Btn {
                            text: detailCol.rice.active ? I18n.tr("APPLIED") : I18n.tr("APPLY THIS RICE")
                            primary: true
                            armed: !detailCol.rice.active
                            onAct: pg.applyRice(pg.selectedSlug, detailCol.chosenLayers())
                        }
                        Btn { text: I18n.tr("DUPLICATE"); onAct: pg.forkRice(pg.selectedSlug) }
                        Btn { text: I18n.tr("SET WALLPAPER"); onAct: riceWallPicker.open() }
                        Btn { text: I18n.tr("VIEW CONFIG"); onAct: configViewer.show(pg.configText) }
                        Btn { text: I18n.tr("EXPORT"); onAct: riceExportPicker.open() }
                        Btn { text: I18n.tr("DELETE"); onAct: pg.delRice(pg.selectedSlug) }
                    }

                    Column {
                        visible: pg.exportedTo !== ""
                        width: parent.width
                        spacing: Tokens.s2
                        Text {
                            text: I18n.tr("EXPORTED TO")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui
                            font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium
                            font.letterSpacing: Tokens.trackLabel
                        }
                        Text {
                            width: parent.width
                            text: pg.exportedTo
                            color: Tokens.ink
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fSmall
                            elide: Text.ElideMiddle
                        }
                        Btn { text: I18n.tr("SHOW IN FILES"); onAct: pg.revealPath(pg.exportedTo) }
                    }
                }
            }
        }
    }

    // ════════════════════════════════════════════════════════════════════════
    // overlays (paperLift + lineStrong, no shadow), one z-plane above the page
    // ════════════════════════════════════════════════════════════════════════

    // cursor theme catalogue
    Item {
        id: cursorPick
        anchors.fill: parent
        visible: false
        z: 200
        function show() { visible = true; picker.open(); }
        MouseArea { anchors.fill: parent; onClicked: cursorPick.visible = false }
        Picker {
            id: picker
            anchors.centerIn: parent
            title: I18n.tr("CURSOR THEME")
            options: pg.cursorThemes
            current: pg.hub ? String(pg.hub.hyprVal("cursor.theme")) : ""
            onChose: (k) => { pg.setKey("cursor.theme", k); cursorPick.visible = false; }
            onDismissed: cursorPick.visible = false
        }
    }

    // image-border image (Borders / IMAGE BORDER); hoisted to page level so its
    // overlay covers the whole page, not just the sheet.
    PickFile {
        id: imgPicker
        title: I18n.tr("Choose a border image")
        onPicked: (p) => { pg.setKey("plugins.imgborders.image", p); imgPicker.active = false; }
        onCanceled: imgPicker.active = false
    }
    // a hidden trigger the image-border cell reaches through onPickRequested is
    // impossible via the sheet, so IMAGE BORDER's picker is opened from a small
    // affordance rendered over its cell. The cell edits the path as text; this
    // button lets the user browse instead.
    Btn {
        id: chooseImageBtn
        visible: pg.tab === "Borders" && !pg.searching && pg.draft["plugins.imgborders.enabled"] === true
        anchors { right: parent.right; bottom: parent.bottom; margins: Tokens.s2 }
        z: 60
        text: I18n.tr("CHOOSE BORDER IMAGE")
        onAct: imgPicker.open()
    }

    // a rice's wallpaper
    PickFile {
        id: riceWallPicker
        title: I18n.tr("Set this rice's wallpaper")
        onPicked: (p) => { pg.setwall(("" + p).replace("file://", "")); riceWallPicker.active = false; }
        onCanceled: riceWallPicker.active = false
    }
    // a rice export target (folders only)
    PickFile {
        id: riceExportPicker
        title: I18n.tr("Export to a folder")
        foldersOnly: true
        startFolder: "file://" + pg.home
        onPicked: (p) => { pg.exportRice(("" + p).replace("file://", "")); riceExportPicker.active = false; }
        onCanceled: riceExportPicker.active = false
    }
    // a shared/exported rice folder to install (folders only)
    PickFile {
        id: riceImportPicker
        title: I18n.tr("Import a rice folder")
        foldersOnly: true
        startFolder: "file://" + pg.home
        onPicked: (p) => { pg.importRiceFolder(("" + p).replace("file://", "")); riceImportPicker.active = false; }
        onCanceled: riceImportPicker.active = false
    }

    // read-only rice manifest viewer
    Item {
        id: configViewer
        anchors.fill: parent
        visible: false
        z: 200
        property string body: ""
        function show(t) { configViewer.body = t; configViewer.visible = true; }
        MouseArea { anchors.fill: parent; onClicked: configViewer.visible = false }
        Rectangle {
            anchors.centerIn: parent
            width: Math.min(parent.width - Tokens.s7 * 2, 760)
            height: Math.min(parent.height - Tokens.s6 * 2, 620)
            radius: Tokens.radius
            color: Tokens.paperLift
            border.width: Tokens.border
            border.color: Tokens.lineStrong
            MouseArea { anchors.fill: parent; onClicked: {} }
            Text {
                id: cvTitle
                anchors { left: parent.left; top: parent.top; leftMargin: Tokens.s5; topMargin: Tokens.s4 }
                text: I18n.tr("RICE CONFIG")
                color: Tokens.ink
                font.family: Tokens.ui
                font.pixelSize: Tokens.fMicro
                font.weight: Font.Medium
                font.letterSpacing: Tokens.trackLabel
            }
            IconBtn {
                anchors { right: parent.right; top: parent.top; rightMargin: Tokens.s4; topMargin: Tokens.s4 }
                glyph: "×"
                onAct: configViewer.visible = false
            }
            Flickable {
                id: cvFlick
                anchors {
                    left: parent.left; right: parent.right
                    top: cvTitle.bottom; bottom: parent.bottom
                    leftMargin: Tokens.s5; rightMargin: Tokens.s3
                    topMargin: Tokens.s4; bottomMargin: Tokens.s4
                }
                clip: true
                contentWidth: width
                contentHeight: cvBody.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }
                TextEdit {
                    id: cvBody
                    width: cvFlick.width - Tokens.s3
                    text: configViewer.body
                    readOnly: true
                    selectByMouse: true
                    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                    color: Tokens.inkDim
                    font.family: Tokens.mono
                    font.pixelSize: Tokens.fSmall
                    selectionColor: Tokens.bone
                    selectedTextColor: Tokens.inkOnBone
                }
            }
        }
    }
}
