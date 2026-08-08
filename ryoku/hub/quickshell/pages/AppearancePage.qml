pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons
import ".."
import "../Singletons"
import "../schema/ThemeCatalog.js" as ThemeCatalog

// Appearance (DESIGN.md, DESKTOP). The desktop's colour, comfort and rice
// controls on the beta18 monochrome instrument. Theme picks the colour scheme
// straight through the settings daemon (theme.theme, the same seam the shell
// sidebar theme picker uses) and, when Follow Wallpaper is picked, the matugen
// tuning knobs; Comfort drives the backlight and night light; Rices browse,
// apply and save whole-desktop looks. The shell owns the rail, the pending-write
// diff and the Save/Revert action bar. Every value is a Token; the only colour
// is the scheme swatches and rice specimens, the thing the user is choosing, so
// they read as data (DESIGN.md section 1).
Item {
    id: pg

    property var hub

    readonly property string pTitle: I18n.tr("Appearance")
    readonly property string pEyebrow: I18n.tr("DESKTOP")
    readonly property string pBlurb: I18n.tr("The palette and scheme, wallpaper, comfort, and rices, applied to your desktop as you make them.")

    property string tab: "Theme"
    readonly property var tabs: ["Theme", "Comfort", "Rices"]
    readonly property bool searching: pg.hub ? (pg.hub.query || "") !== "" : false

    readonly property string home: Quickshell.env("HOME") || ""

    // ════════════════════════════════════════════════════════════════════════
    // Theme: the colour scheme (instant, through the settings seam) and, for
    // Follow Wallpaper, the matugen tuning knobs (staged; written on Save via
    // applyTheme, dropped by revertTheme). The shared action bar drives the
    // staged part through hub.pageDirty / savePage / revertPage.
    // ════════════════════════════════════════════════════════════════════════
    // Colour scheme: Follow Wallpaper / Default (the two dynamic variants) or one
    // of the 57 named catalog palettes. Written straight through the daemon
    // settings seam (theme.theme) -- the SAME key the sidebar theme picker reads
    // and writes, so the two are one truth. The daemon resolves the selected
    // palette into shell.json themePalette and fans it into the shell and every
    // app. This applies instantly (like the sidebar), so it sits outside the
    // staged Save the wallpaper-tuning knobs ride.
    readonly property string scheme: { Settings.revision; return Settings.get("theme.theme") || ""; }
    function setScheme(k) { if (k) Settings.patch("theme.theme", k); }
    // Installed RyoStore schemes, read live from the daemon catalog and listed
    // beside the built-ins so a downloaded theme is pickable here too.
    readonly property var userSchemes: UserSchemes.schemes
    function schemeName(id) {
        for (var i = 0; i < ThemeCatalog.schemes.length; i++)
            if (ThemeCatalog.schemes[i].id === id)
                return ThemeCatalog.schemes[i].label;
        for (var j = 0; j < pg.userSchemes.length; j++)
            if (pg.userSchemes[j].id === id)
                return pg.userSchemes[j].label;
        return id === "" ? I18n.tr("Loading") : id;
    }

    // Ryoku default: reset the whole desktop to the shipped signature in one
    // click, via `ryoku-hub hypr ryoku-theme`. A distinct one-shot reset.
    function applyRyokuTheme() { Settings.patch("theme.theme", "Default"); ryokuThemeProc.running = true; }
    Process { id: ryokuThemeProc; command: ["ryoku-hub", "hypr", "ryoku-theme"]; stdout: StdioCollector { onStreamFinished: { pg.refreshMatugen(); } } }

    // ════════════════════════════════════════════════════════════════════════
    // Colour generation: how matugen reads the wallpaper. Applied instantly, the
    // same as the scheme above -- these used to stage behind the shared Save,
    // which read as "the mode does nothing" because nothing happened until you
    // found the action bar.
    //
    // Only the keys this page owns are sent; the backend merges them onto what is
    // stored, so the roster and the app-theming toggle it does not show cannot be
    // clobbered by a save from here.
    // ════════════════════════════════════════════════════════════════════════
    property var matugenCfg: ({ "mode": "smart", "contrast": 0.0 })

    readonly property string genMode: pg.matugenCfg.mode || "smart"
    readonly property real genContrast: pg.matugenCfg.contrast || 0.0

    function refreshMatugen() { matugenGetProc.running = true; }

    // Mirror the value locally so the control tracks the drag, then write. The
    // slider debounces; a Seg click is discrete and writes at once.
    function setGen(key, value) {
        var c = Object.assign({}, pg.matugenCfg);
        c[key] = value;
        pg.matugenCfg = c;
        var patch = {};
        patch[key] = value;
        pg.pendingGen = Object.assign({}, pg.pendingGen, patch);
        genWrite.restart();
    }
    property var pendingGen: ({})
    Timer {
        id: genWrite
        interval: 220
        onTriggered: {
            matugenSetProc.command = ["ryoku-hub", "hypr", "matugen", "set", JSON.stringify(pg.pendingGen)];
            matugenSetProc.running = true;
            pg.pendingGen = ({});
        }
    }

    Process {
        id: matugenGetProc
        command: ["ryoku-hub", "hypr", "matugen", "get"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var parsed = JSON.parse(this.text);
                    if (parsed)
                        pg.matugenCfg = parsed;
                } catch(e) {}
            }
        }
    }
    Process { id: matugenSetProc }


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
    // Rices: installed whole-desktop looks. RyoStore owns browsing and install;
    // this page keeps local capture, activation, import, export, and deletion.
    // ════════════════════════════════════════════════════════════════════════
    property var rices: []
    property bool ricesLoading: true
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
        if (pg.selectedSlug !== "") pg.loadFiles();
    }

    function reloadRices() {
        pg.ricesLoading = true;
        listProc.running = true;
        if (pg.selectedSlug !== "") pg.loadFiles();
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
    function browseRices() { Quickshell.execDetached(["ryostore", "open", "rices"]); }
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
        if (pg.tab === "Comfort") pg.refreshComfort();
        else if (pg.tab === "Rices") pg.reloadRices();
    }
    Component.onCompleted: { pg.refreshComfort(); pg.reloadRices(); pg.refreshMatugen(); }

    // ════════════════════════════════════════════════════════════════════════
    // small shared pieces
    // ════════════════════════════════════════════════════════════════════════

    // a colour-scheme card: the sidebar's swatch-card picker in the Hub's ink
    // vocabulary. A named palette shows its own surface, name and a two-by-three
    // swatch grid (the swatches are data, the one sanctioned chroma); the two
    // dynamic variants (Follow, Default) show a tracked word instead. One tap
    // writes theme.theme through the settings seam; the selected card is ringed.
    component SchemeCard: Rectangle {
        id: scard
        property var scheme: ({})
        readonly property bool dyn: scard.scheme.dynamic === true
        readonly property var sw: scard.dyn ? [] : (scard.scheme.sw || [])
        readonly property bool sel: pg.scheme === scard.scheme.id

        width: 104
        height: 128
        radius: Tokens.radius
        color: "transparent"
        border.width: scard.sel ? 2 : Tokens.border
        border.color: scard.sel ? Tokens.ink : (scHov.hovered ? Tokens.lineStrong : Tokens.line)
        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

        Rectangle {
            id: scPrev
            anchors.fill: parent
            anchors.margins: scard.sel ? 2 : Tokens.border
            radius: Tokens.radius - 1
            color: scard.dyn || scard.sw.length === 0 ? "transparent" : scard.sw[0]
            clip: true

            Text {
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: Tokens.s2 }
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                text: scard.scheme.label || ""
                color: scard.dyn ? Tokens.ink : (scard.sw.length > 1 ? scard.sw[1] : Tokens.ink)
                font.family: Tokens.ui
                font.pixelSize: Tokens.fTiny
            }

            Text {
                visible: scard.dyn
                anchors.centerIn: parent
                text: scard.scheme.id === "Wallpaper" ? I18n.tr("LIVE") : I18n.tr("MONO")
                color: Tokens.inkMuted
                font.family: Tokens.mono
                font.pixelSize: Tokens.fMicro
                font.letterSpacing: Tokens.trackMark
            }

            Column {
                visible: !scard.dyn
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 22
                spacing: 6
                Row {
                    spacing: 6
                    Repeater {
                        model: scard.dyn ? [] : [scard.sw[1], scard.sw[2], scard.sw[3]]
                        delegate: Rectangle { required property color modelData; width: 14; height: 14; color: modelData }
                    }
                }
                Row {
                    spacing: 6
                    Repeater {
                        model: scard.dyn ? [] : [scard.sw[4], scard.sw[5], scard.sw[6]]
                        delegate: Rectangle { required property color modelData; width: 14; height: 14; color: modelData }
                    }
                }
            }

            Rectangle {
                visible: scard.sel
                anchors { left: parent.left; bottom: parent.bottom; leftMargin: Tokens.s2; bottomMargin: Tokens.s2 }
                width: 8
                height: 8
                radius: 4
                color: scard.dyn ? Tokens.ink : (scard.sw.length > 1 ? scard.sw[1] : Tokens.ink)
            }
        }

        HoverHandler { id: scHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pg.setScheme(scard.scheme.id) }
    }

    // A local rice tile: monochrome chrome around its colour preview.
    component RiceCard: Rectangle {
        id: card
        property var rice: ({})
        signal opened()

        readonly property string preview: card.rice.preview || card.rice.posterUrl || ""
        readonly property bool active: !!card.rice.active
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
                visible: card.active
                Rectangle {
                    visible: card.active
                    width: 6; height: 6; radius: 3
                    color: Tokens.ink
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: I18n.tr("ACTIVE")
                    color: Tokens.ink
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

                // ── COLOUR GENERATION: how matugen reads the wallpaper. First,
                // because it is what the live scheme is actually made of; shown only
                // for the live pick, since a fixed palette needs no extraction.
                SettingCard {
                    visible: pg.scheme === "Wallpaper"
                    width: wallCol.width
                    title: I18n.tr("COLOUR GENERATION")
                    Text {
                        width: parent.width
                        leftPadding: Tokens.s4; rightPadding: Tokens.s4
                        topPadding: Tokens.s3; bottomPadding: Tokens.s1
                        text: I18n.tr("Live colours are read from the wallpaper. Mode picks a light or dark palette, or follows the picture's own brightness; contrast pushes the palette apart. Both apply as you set them.")
                        color: Tokens.inkMuted; font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                    }
                    SettingRow {
                        anchors.left: parent.left; anchors.right: parent.right
                        divider: true
                        block: true
                        label: I18n.tr("Mode")
                        Seg {
                            anchors.left: parent.left; anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            options: ["DARK", "LIGHT", "SMART"]
                            current: pg.genMode.toUpperCase()
                            onChose: (k) => pg.setGen("mode", k.toLowerCase())
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left; anchors.right: parent.right
                        divider: true
                        label: I18n.tr("Contrast")
                        value: String(pg.genContrast)
                        controlWidth: Math.min(240, Math.max(160, Math.round(wallCol.width * 0.34)))
                        Slid {
                            anchors.fill: parent
                            from: -1.0; to: 1.0
                            value: pg.genContrast
                            onModified: (v) => pg.setGen("contrast", Math.round(v * 100) / 100)
                        }
                    }
                }

                // ── COLOUR SCHEME: the live wallpaper pick, the shipped Default, or
                // one of the 57 named palettes. Applies instantly through the daemon
                // settings seam (theme.theme) -- the same key the sidebar theme picker
                // writes, so the two stay one truth. The named palettes sit behind a
                // drawer: two picks carry the everyday choice, and the wall of 57 is
                // there when it is wanted rather than in the way.
                SettingCard {
                    id: schemeCard
                    width: wallCol.width
                    title: I18n.tr("COLOUR SCHEME")
                    property bool themesOpen: false

                    Text {
                        width: parent.width
                        leftPadding: Tokens.s4; rightPadding: Tokens.s4
                        topPadding: Tokens.s3; bottomPadding: Tokens.s2
                        text: I18n.tr("Follow the wallpaper for live colours, keep the Ryoku default, or lock one of the named palettes. The same picker as the sidebar; the daemon retints the shell and every app to match.")
                        color: Tokens.inkMuted; font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                    }

                    // the sidebar's swatch-card picker, kept intact -- inset into the
                    // card body. Always out: the two dynamic variants plus the named
                    // palette in use, so the current pick is never hidden; the wall of
                    // 57 sits behind the drawer.
                    Column {
                        width: parent.width
                        leftPadding: Tokens.s4; rightPadding: Tokens.s4; bottomPadding: Tokens.s4
                        spacing: Tokens.s3

                        Flow {
                            width: parent.width - Tokens.s4 * 2
                            spacing: Tokens.s3
                            Repeater {
                                model: ThemeCatalog.schemes.filter(s => s.dynamic === true || s.id === pg.scheme).concat(pg.userSchemes.filter(s => s.id === pg.scheme))
                                delegate: SchemeCard { required property var modelData; scheme: modelData }
                            }
                        }

                        Row {
                            spacing: Tokens.s3
                            Btn {
                                text: schemeCard.themesOpen ? I18n.tr("HIDE THEMES") : I18n.tr("ALL THEMES")
                                onAct: { schemeCard.themesOpen = !schemeCard.themesOpen; if (schemeCard.themesOpen) UserSchemes.refresh(); }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: I18n.tr("%1 named palettes").arg(ThemeCatalog.schemes.filter(s => s.dynamic !== true).length + pg.userSchemes.length)
                                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                            }
                        }

                        Item {
                            width: parent.width - Tokens.s4 * 2
                            height: schemeCard.themesOpen ? themeFlow.height : 0
                            clip: true
                            visible: height > 0.5
                            opacity: schemeCard.themesOpen ? 1 : 0
                            Behavior on height { NumberAnimation { duration: Tokens.move; easing.type: Tokens.ease } }
                            Behavior on opacity { NumberAnimation { duration: Tokens.snap } }
                            Flow {
                                id: themeFlow
                                width: parent.width
                                spacing: Tokens.s3
                                Repeater {
                                    model: ThemeCatalog.schemes.filter(s => s.dynamic !== true).concat(pg.userSchemes)
                                    delegate: SchemeCard { required property var modelData; scheme: modelData }
                                }
                            }
                        }
                    }
                }

                // ── RYOKU DEFAULT ──
                SettingCard {
                    width: wallCol.width
                    title: I18n.tr("RYOKU DEFAULT")
                    Text {
                        width: parent.width
                        leftPadding: Tokens.s4; rightPadding: Tokens.s4
                        topPadding: Tokens.s3; bottomPadding: Tokens.s1
                        text: I18n.tr("Reset the whole desktop to the Ryoku signature: paper frame bars, square corners, Space Grotesk, and the grainy mono palette.")
                        color: Tokens.inkMuted; font.family: Tokens.ui
                        font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                    }
                    SettingRow {
                        anchors.left: parent.left; anchors.right: parent.right
                        divider: true
                        footH: 32
                        label: I18n.tr("Apply the Ryoku theme")
                        Btn {
                            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                            text: I18n.tr("APPLY RYOKU THEME"); primary: true
                            onAct: pg.applyRyokuTheme()
                        }
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

                SettingCard {
                    width: comfortCol.width
                    title: I18n.tr("BACKLIGHT")
                    SettingRow {
                        anchors.left: parent.left; anchors.right: parent.right
                        label: I18n.tr("Brightness"); unit: "%"
                        desc: I18n.tr("Hardware backlight, applied at once, floors at 5% to stay visible.")
                        value: String(pg.brightness < 0 ? 100 : pg.brightness)
                        changed: false
                        controlWidth: Math.min(240, Math.max(160, Math.round(comfortCol.width * 0.34)))
                        Slid {
                            anchors.fill: parent
                            from: 5; to: 100
                            value: pg.brightness < 0 ? 100 : pg.brightness
                            onModified: (v) => pg.setBrightness(v)
                        }
                    }
                }

                SettingCard {
                    width: comfortCol.width
                    title: I18n.tr("NIGHT LIGHT")
                    SettingRow {
                        anchors.left: parent.left; anchors.right: parent.right
                        label: I18n.tr("Warm the screen")
                        desc: I18n.tr("Cuts blue light for the evening, stays on across sessions.")
                        changed: false
                        controlWidth: 54
                        Sw {
                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                            on: pg.nightOn
                            onToggled: (v) => pg.setNight(v)
                        }
                    }
                    SettingRow {
                        anchors.left: parent.left; anchors.right: parent.right
                        divider: true
                        label: I18n.tr("Temperature"); unit: "K"
                        desc: I18n.tr("Lower Kelvin is warmer, saved only while the light is on.")
                        value: String(pg.nightTemp)
                        changed: false
                        controlWidth: Math.min(240, Math.max(160, Math.round(comfortCol.width * 0.34)))
                        Slid {
                            anchors.fill: parent
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

                    Btn {
                        text: I18n.tr("BROWSE RYOSTORE")
                        onAct: pg.browseRices()
                    }

                    // My rices
                    Column {
                        width: parent.width
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
                                text: I18n.tr("Tune your desktop, then Save current setup to make your first rice, or browse RyoStore to install one.")
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
