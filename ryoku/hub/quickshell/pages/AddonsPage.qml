pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Add-ons (DESIGN.md section 8). Home for the shell plugins the user has
// installed: a master list read live from plugins.json, and a detail per
// plugin that renders its own settings from the manifest schema, toggles it on
// or off, chooses where it sits, and removes it. Browsing and installing new
// ones lives in the Store; this page manages what is already here.
//
// This is a full-bleed page: it owns the whole content region, draws its own
// head, and every action applies immediately (the Store's dirty/Save loop does
// not apply -- writes go through `ryoku-plugins-place` straight into
// plugins.json, and the running shell watches the file and retunes live). No
// unsaved state, so no action bar. Master/detail swap through a Loader.
//
// Backend, ported verbatim from the warm-dark AddonsPage: installed list =
// `discover.sh --all`; catalogue (for update detection) = `ryoku-hub extras
// plugincatalog`; enable/host/placement/settings = `ryoku-plugins-place`;
// update = `ryoku-hub extras plugin <id>`; remove = forget + pluginremove.
// Every value is a Token; no colour, no bitmap previews (a raw screenshot on a
// monochrome sheet would break the palette, so cards are typographic).
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    // ── installed-management state ──────────────────────────────────────────
    property var plugins: []        // discover.sh --all: [{ id, dir, manifest, placement }]
    property var catalog: []         // plugincatalog: available versions, for the Update marker
    property string selId: ""        // "" = master list; else the open plugin's id
    property string busyId: ""        // id currently installing/removing
    property bool confirmRemove: false // the destructive-confirm plate is up
    property bool loaded: false        // discover.sh has answered at least once

    // hub.query carries the rail search text; empty means no filter.
    readonly property string query: (pg.hub && pg.hub.query) ? ("" + pg.hub.query) : ""

    // the selected plugin, re-derived from selId so it stays fresh across a
    // refresh (the process round-trip swaps the whole plugins array).
    readonly property var sel: {
        for (var i = 0; i < pg.plugins.length; i++)
            if (pg.plugins[i].id === pg.selId)
                return pg.plugins[i];
        return null;
    }

    // the master list, filtered by the rail search.
    readonly property var shown: {
        var q = pg.query.trim().toLowerCase();
        if (q === "")
            return pg.plugins;
        return pg.plugins.filter(function (p) {
            var m = p.manifest || {};
            var name = ("" + (m.name || p.id || "")).toLowerCase();
            return name.indexOf(q) >= 0 || ("" + p.id).toLowerCase().indexOf(q) >= 0;
        });
    }

    readonly property string shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string script: (pg.shellDir && pg.shellDir.length > 0)
        ? pg.shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/discover.sh"

    // framePopout | desktopWidget -> readable label, and back.
    function hostLabel(key) {
        return key === "framePopout" ? "Frame popout" : key === "desktopWidget" ? "Desktop widget" : key;
    }
    function hostKey(label) {
        return label === "Frame popout" ? "framePopout" : label === "Desktop widget" ? "desktopWidget" : label;
    }

    function refresh() { listProc.running = false; listProc.running = true; }
    function loadCatalog() { catProc.running = false; catProc.running = true; }
    function catalogEntry(id) {
        for (var i = 0; i < pg.catalog.length; i++)
            if (pg.catalog[i].id === id)
                return pg.catalog[i];
        return null;
    }
    // semver compare: 1 if a>b, 0 equal, -1 if a<b. missing parts = 0.
    function cmpSemver(a, b) {
        var pa = String(a || "0").split(".").map(function (n) { return parseInt(n, 10) || 0; });
        var pb = String(b || "0").split(".").map(function (n) { return parseInt(n, 10) || 0; });
        for (var i = 0; i < Math.max(pa.length, pb.length); i++) {
            var x = pa[i] || 0, y = pb[i] || 0;
            if (x !== y)
                return x < y ? -1 : 1;
        }
        return 0;
    }
    // an installed plugin -> the newer catalogue version, or "" when up to date
    // / unknown. Drives the Update marker and the detail's Update button.
    function updateFor(pl) {
        var inst = (pl && pl.manifest && pl.manifest.version) ? pl.manifest.version : "";
        var ce = pg.catalogEntry(pl ? pl.id : "");
        var avail = ce ? (ce.version || "") : "";
        if (!inst || !avail)
            return "";
        return pg.cmpSemver(avail, inst) > 0 ? avail : "";
    }
    function install(id) {
        if (!id)
            return;
        pg.busyId = id;
        installProc.command = ["ryoku-hub", "extras", "plugin", id];
        installProc.running = true;
    }
    function place(id, field, a, b, c, d) {
        if (!id)
            return;
        var args = ["ryoku-plugins-place", id, field];
        for (var v of [a, b, c, d])
            if (v !== undefined)
                args.push("" + v);
        placeProc.command = args;
        placeProc.running = true;
    }
    function setSetting(id, key, value) {
        if (!id)
            return;
        var obj = {};
        obj[key] = value;
        settingsProc.command = ["ryoku-plugins-place", id, "settings", JSON.stringify(obj)];
        settingsProc.running = true;
    }
    // remove drops the whole plugins.json entry (forget) then deletes the
    // data-dir plugin via the symlink-safe backend (a dev plugin is a symlink
    // into the checkout; rm -rf would gut the repo).
    function removePlugin(id) {
        if (!id)
            return;
        pg.busyId = id;
        pg.place(id, "forget");
        rmProc.command = ["ryoku-hub", "extras", "pluginremove", id];
        rmProc.running = true;
    }

    Component.onCompleted: { pg.refresh(); pg.loadCatalog(); }

    Process {
        id: listProc
        command: ["bash", pg.script, "--all"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.plugins = JSON.parse(text || "[]"); } catch (e) { pg.plugins = []; }
                pg.loaded = true;
            }
        }
    }
    Process { id: placeProc; onExited: pg.refresh() }
    Process { id: settingsProc; onExited: pg.refresh() }
    Process { id: rmProc; onExited: { pg.busyId = ""; pg.selId = ""; pg.confirmRemove = false; pg.refresh(); } }
    Process {
        id: catProc
        command: ["ryoku-hub", "extras", "plugincatalog"]
        stdout: StdioCollector {
            onStreamFinished: { try { pg.catalog = (JSON.parse(text || "{}").plugins) || []; } catch (e) { pg.catalog = []; } }
        }
    }
    Process { id: installProc; onExited: { pg.busyId = ""; pg.refresh(); pg.loadCatalog(); } }

    // ── head: eyebrow, Fraunces title, blurb (matches every page) ───────────
    Column {
        id: head
        anchors { left: parent.left; right: parent.right; top: parent.top }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s6
        spacing: Tokens.s2

        Row {
            spacing: Tokens.s2
            Rectangle {
                width: 16; height: 1; color: Tokens.ink
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "力"; color: Tokens.ink; font.family: Tokens.jp
                font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "ADD-ONS"; color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: "Installed"; color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: "The shell plugins you have installed. Open one to tune its options, choose where it sits, enable or remove it. Changes apply to your desktop live; browse and install more from the Store."
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
    }

    // marginalia dressing the head's empty right margin (eyebrow line). Ink only.
    Marginalia {
        anchors { right: parent.right; top: head.top }
        anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s1
        kana: "拡張"
        index: "04"; label: "ADD-ONS"
        glyph: "asanoha"; glyph2: "meander"
    }

    // ── the body: a Loader swaps master (list) and detail (one plugin) ──────
    Loader {
        id: body
        anchors {
            left: parent.left; right: parent.right
            top: head.bottom; bottom: parent.bottom
            leftMargin: Tokens.s6; rightMargin: Tokens.s6
            topMargin: Tokens.s5; bottomMargin: Tokens.s6
        }
        sourceComponent: pg.selId === "" ? masterComp : detailComp
        onLoaded: {
            if (!item)
                return;
            item.opacity = 0;
            fade.restart();
        }
    }
    // content exchange -> swap token; nothing travels, so a plain fade is right.
    NumberAnimation {
        id: fade
        target: body.item; property: "opacity"; to: 1
        duration: Tokens.swap; easing.type: Tokens.ease
    }

    // ── master: the installed list ──────────────────────────────────────────
    Component {
        id: masterComp

        Item {
            id: master

            // section head: dot + PLUGINS + leader + count + refresh.
            Item {
                id: sect
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 32

                Row {
                    id: sectLabel
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s2
                    Rectangle {
                        width: 4; height: 4; color: Tokens.ink
                        anchors.verticalCenter: parent.verticalCenter
                    }
                    Text {
                        text: "PLUGINS"; color: Tokens.ink; font.family: Tokens.ui
                        font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                        font.letterSpacing: Tokens.trackMark
                        anchors.verticalCenter: parent.verticalCenter
                    }
                }

                Row {
                    id: sectActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s3

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        // an entry count is file-truth chrome, so mono.
                        text: pg.plugins.length + (pg.plugins.length === 1 ? " PLUGIN" : " PLUGINS")
                        color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                    }
                    // re-scan installed plugins (installs happen in the Store).
                    IconBtn {
                        anchors.verticalCenter: parent.verticalCenter
                        glyph: "\u21bb"
                        onAct: pg.refresh()
                    }
                }

                Rectangle {
                    anchors.left: sectLabel.right; anchors.right: sectActions.left
                    anchors.leftMargin: Tokens.s3; anchors.rightMargin: Tokens.s3
                    anchors.verticalCenter: parent.verticalCenter
                    height: 1; color: Tokens.lineSoft
                }
            }

            Flickable {
                id: flick
                anchors {
                    left: parent.left; right: parent.right
                    top: sect.bottom; bottom: instDecor.visible ? instDecor.top : parent.bottom
                    topMargin: Tokens.s4; bottomMargin: instDecor.visible ? Tokens.s4 : 0
                }
                contentWidth: width
                contentHeight: Math.max(col.height, height)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                Column {
                    id: col
                    width: flick.width - Tokens.s3   // reserve a lane for the scroll rail
                    spacing: Tokens.s2

                    Repeater {
                        model: pg.shown

                        delegate: Rectangle {
                            id: card
                            required property var modelData
                            readonly property var man: card.modelData.manifest || ({})
                            readonly property var place: card.modelData.placement || ({})
                            readonly property bool on: card.place.enabled === true
                            readonly property string host: (card.place.host)
                                ? card.place.host
                                : ((card.man.defaults && card.man.defaults.host) ? card.man.defaults.host : "framePopout")
                            readonly property int settingsCount: (card.man.metadata && card.man.metadata.settings)
                                ? card.man.metadata.settings.length : 0
                            readonly property string upd: pg.updateFor(card.modelData)

                            width: col.width
                            height: 64
                            radius: Tokens.radius
                            color: ch.hovered ? Tokens.tint5 : "transparent"
                            border.width: Tokens.border
                            border.color: ch.hovered ? Tokens.lineStrong : Tokens.line
                            Behavior on color { ColorAnimation { duration: Tokens.snap } }
                            Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

                            HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
                            TapHandler { onTapped: pg.selId = card.modelData.id }

                            // name + meta.
                            Column {
                                anchors.left: parent.left; anchors.leftMargin: Tokens.s4
                                anchors.right: right.left; anchors.rightMargin: Tokens.s3
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s1

                                Text {
                                    width: parent.width
                                    text: card.man.name || card.modelData.id
                                    color: Tokens.ink; font.family: Tokens.ui
                                    font.pixelSize: Tokens.fRow; font.weight: Font.Medium
                                    elide: Text.ElideRight
                                }
                                Text {
                                    width: parent.width
                                    text: pg.hostLabel(card.host)
                                        + (card.settingsCount > 0 ? "  ·  " + card.settingsCount + (card.settingsCount === 1 ? " setting" : " settings") : "")
                                    color: Tokens.inkMuted; font.family: Tokens.ui
                                    font.pixelSize: Tokens.fMicro
                                    elide: Text.ElideRight
                                }
                            }

                            // right cluster: update marker, status chip, caret.
                            Row {
                                id: right
                                anchors.right: parent.right; anchors.rightMargin: Tokens.s4
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s3

                                // a version string is file-truth, so mono. This
                                // only flags availability; the action is in detail.
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    visible: card.upd !== ""
                                    text: "UPDATE " + card.upd
                                    color: Tokens.ink; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                                }

                                // status: enabled inverts (the ON member of a set).
                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: pip.implicitWidth + 16
                                    height: 20
                                    radius: Tokens.radius
                                    color: card.on ? Tokens.bone : "transparent"
                                    border.width: card.on ? 0 : Tokens.border
                                    border.color: Tokens.line
                                    Text {
                                        id: pip
                                        anchors.centerIn: parent
                                        text: card.on ? "ON" : "OFF"
                                        color: card.on ? Tokens.inkOnBone : Tokens.inkFaint
                                        font.family: Tokens.ui; font.pixelSize: Tokens.fTiny
                                        font.weight: Font.Medium; font.letterSpacing: 0.6
                                    }
                                }

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\u203a"
                                    color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                }
                            }
                        }
                    }
                }
            }

            // empty state, gated on load so it does not flash before data lands.
            Text {
                anchors.centerIn: flick
                visible: pg.loaded && pg.plugins.length === 0
                text: "No add-ons installed. Open the Store to browse and install."
                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
            }
            // no-results state, when a search filters everything out.
            Text {
                anchors.centerIn: flick
                visible: pg.plugins.length > 0 && pg.shown.length === 0
                text: "No add-ons match your search."
                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
            }

            // fills the dead grid slot below a short plugin list, per DESIGN.md
            // section 12: a poster gives the section its face. Ink-only, holds no
            // control; hidden while searching so results own the full column.
            Decor {
                id: instDecor
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: Math.min(300, parent.height - Tokens.cellH * 2 - Tokens.s5)
                visible: pg.loaded && pg.shown.length > 0 && pg.query.trim() === "" && height > 140
                title: "拡張"; sub: "アドオン"
                tate: "力を継ぎ足す"
                caption: "Plugins extend the shell: live surfaces you install from the Store."
                readout: ["SOURCE|plugins.json", "APPLY|live", "SITS|frame · desktop", "SCOPE|per-plugin"]
                code: "ADDON-04"; seal: "拡"; boxId: "addons.installed"; seed: 5; ditherFreq: 1.0
            }
        }
    }

    // ── detail: one plugin's placement + settings ───────────────────────────
    Component {
        id: detailComp

        Item {
            id: detail

            readonly property var sel: pg.sel || ({})
            readonly property var man: detail.sel.manifest || ({})
            readonly property var place: detail.sel.placement || ({})
            readonly property var schema: (detail.man.metadata && detail.man.metadata.settings) || []
            readonly property bool enabled: detail.place.enabled === true
            readonly property string host: (detail.place.host)
                ? detail.place.host
                : ((detail.man.defaults && detail.man.defaults.host) ? detail.man.defaults.host : "framePopout")
            readonly property var hosts: (detail.man.hosts || []).filter(function (h) {
                return h === "framePopout" || h === "desktopWidget";
            })
            readonly property string upd: pg.updateFor(detail.sel)

            // ── header: back + name + version .... update + remove ──
            Item {
                id: hdr
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: 40

                IconBtn {
                    id: backBtn
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    glyph: "\u2039"
                    onAct: pg.selId = ""
                }

                Row {
                    id: acts
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s3

                    // Update: only when the catalogue carries a newer version.
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: detail.upd !== ""
                        text: pg.busyId === detail.sel.id ? "UPDATING" : ("UPDATE " + detail.upd)
                        armed: pg.busyId === ""
                        onAct: pg.install(detail.sel.id)
                    }
                    // Remove: destructive, so it arms the confirm plate first.
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "REMOVE"
                        onAct: pg.confirmRemove = true
                    }
                }

                Text {
                    id: nameT
                    anchors.left: backBtn.right; anchors.leftMargin: Tokens.s3
                    anchors.right: verT.left; anchors.rightMargin: Tokens.s2
                    anchors.verticalCenter: parent.verticalCenter
                    text: (detail.man.name) ? detail.man.name : (detail.sel.id || "")
                    color: Tokens.ink; font.family: Tokens.ui
                    font.pixelSize: Tokens.fValue; font.weight: Font.Medium
                    elide: Text.ElideRight
                }
                Text {
                    id: verT
                    anchors.right: acts.left; anchors.rightMargin: Tokens.s4
                    anchors.verticalCenter: parent.verticalCenter
                    visible: text !== ""
                    text: (detail.man.version) ? ("v" + detail.man.version) : ""
                    color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                }
            }

            Flickable {
                id: dflick
                anchors {
                    left: parent.left; right: parent.right
                    top: hdr.bottom; bottom: parent.bottom
                    topMargin: Tokens.s5
                }
                contentWidth: width
                contentHeight: Math.max(dcol.height, height)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                Column {
                    id: dcol
                    width: dflick.width - Tokens.s3
                    spacing: Tokens.s5

                    // ── Placement: enable, host, and where a popout sits ──
                    Column {
                        width: parent.width
                        spacing: Tokens.s3

                        Item {
                            width: parent.width; height: 20
                            Row {
                                id: pHead
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s2
                                Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "PLACEMENT"; color: Tokens.ink; font.family: Tokens.ui
                                    font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                                    font.letterSpacing: Tokens.trackMark
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Rectangle {
                                anchors.left: pHead.right; anchors.leftMargin: Tokens.s3
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1; color: Tokens.lineSoft
                            }
                        }

                        // Enabled: runs it on the desktop, or keeps it dormant.
                        Item {
                            width: parent.width; height: 30
                            Text {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: "Enabled"
                                color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                            }
                            Sw {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                on: detail.enabled
                                onToggled: (v) => pg.place(detail.sel.id, "enabled", v ? "true" : "false")
                            }
                        }

                        // Show as: only when the plugin offers more than one home.
                        Item {
                            width: parent.width; height: 30
                            visible: detail.hosts.length > 1
                            Text {
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                text: "Show as"
                                color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                            }
                            Seg {
                                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                options: detail.hosts.map(function (h) { return pg.hostLabel(h); })
                                current: pg.hostLabel(detail.host)
                                onChose: (label) => pg.place(detail.sel.id, "host", pg.hostKey(label))
                            }
                        }

                        // ── frame-popout placement editor ──
                        // Screen-proportioned stage: pick an edge for the popout
                        // to grow from and drag it along that edge (start | end;
                        // the centre third of every edge is reserved for the
                        // island/mixer/power menu and shown struck out). Edits
                        // write live via ryoku-plugins-place. Desktop widgets do
                        // not come through here (they are placed on the
                        // wallpaper), so this renders for framePopout only.
                        Item {
                            id: placer
                            width: parent.width
                            implicitHeight: 230
                            visible: detail.enabled && detail.host === "framePopout"

                            readonly property var fp: (detail.place && detail.place.framePopout) ? detail.place.framePopout : ({})
                            readonly property string edge: placer.fp.edge ? placer.fp.edge : "right"
                            readonly property string align: placer.fp.align ? placer.fp.align : "start"
                            // a live mirror so a drag snaps instantly, before the
                            // ryoku-plugins-place round-trip refreshes the truth.
                            property string alignLocal: placer.align
                            onAlignChanged: placer.alignLocal = placer.align
                            readonly property bool vertical: placer.edge === "left" || placer.edge === "right"
                            function hoverW() { return placer.fp.hoverW ? placer.fp.hoverW : 320; }
                            function hoverH() { return placer.fp.hoverH ? placer.fp.hoverH : 16; }
                            function chipX() {
                                var m = 10;
                                return placer.edge === "left" ? m
                                     : placer.edge === "right" ? stage.width - chip.width - m
                                     : (placer.alignLocal === "end" ? stage.width - chip.width - m : m);
                            }
                            function chipY() {
                                var m = 10;
                                return placer.edge === "top" ? m
                                     : placer.edge === "bottom" ? stage.height - chip.height - m
                                     : (placer.alignLocal === "end" ? stage.height - chip.height - m : m);
                            }

                            Rectangle {
                                id: stage
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                width: Math.min(placer.width, (placer.implicitHeight - 28) * 1.6)   // ~16:10
                                height: placer.implicitHeight - 28
                                radius: Tokens.radius
                                color: "transparent"   // no gradient; depth is the hairline
                                border.width: Tokens.border
                                border.color: Tokens.line
                                clip: true

                                // faint inner screen frame, so it reads as "your display".
                                Rectangle {
                                    anchors.fill: parent; anchors.margins: 8
                                    radius: Tokens.radius; color: "transparent"
                                    border.width: Tokens.border; border.color: Tokens.lineSoft
                                }

                                Text {
                                    anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 10
                                    text: "LIVE PLACEMENT"
                                    color: Tokens.inkFaint; font.family: Tokens.mono
                                    font.pixelSize: Tokens.fTiny; font.weight: Font.Medium
                                    font.letterSpacing: 2
                                }

                                // reserved centre-third of the chosen edge.
                                Rectangle {
                                    id: band
                                    readonly property real m: 10
                                    readonly property real bandThickness: placer.vertical ? 64 : 60
                                    x: placer.edge === "left" ? m
                                     : placer.edge === "right" ? parent.width - bandThickness - m
                                     : parent.width / 3
                                    y: placer.edge === "top" ? m
                                     : placer.edge === "bottom" ? parent.height - bandThickness - m
                                     : parent.height / 3
                                    width: placer.vertical ? bandThickness : parent.width / 3
                                    height: placer.vertical ? parent.height / 3 : bandThickness
                                    radius: Tokens.radius
                                    color: Tokens.tint5
                                    Canvas {
                                        anchors.fill: parent
                                        onPaint: {
                                            var ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = Tokens.inkFaint.toString();
                                            ctx.lineWidth = 1;
                                            ctx.setLineDash([4, 3]);
                                            ctx.strokeRect(0.5, 0.5, width - 1, height - 1);
                                        }
                                        onWidthChanged: requestPaint()
                                        onHeightChanged: requestPaint()
                                    }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "reserved"
                                        color: Tokens.inkFaint; font.family: Tokens.mono
                                        font.pixelSize: Tokens.fTiny; font.letterSpacing: 1.5
                                    }
                                }

                                // the popout body: a chip docked to the edge, drag
                                // it along the edge to flip align (start | end).
                                Rectangle {
                                    id: chip
                                    width: placer.vertical ? 64 : 96
                                    height: placer.vertical ? 96 : 60
                                    radius: Tokens.radius
                                    color: Tokens.paperLift
                                    border.width: Tokens.border
                                    border.color: Tokens.ink
                                    x: placer.chipX()
                                    y: placer.chipY()

                                    Text {
                                        anchors.centerIn: parent
                                        text: "popout"
                                        color: Tokens.ink; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
                                    }

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        drag.target: chip
                                        drag.axis: placer.vertical ? Drag.YAxis : Drag.XAxis
                                        onReleased: {
                                            var pos, span;
                                            if (placer.vertical) { pos = chip.y + chip.height / 2; span = stage.height; }
                                            else { pos = chip.x + chip.width / 2; span = stage.width; }
                                            var a = (pos / span) < 0.5 ? "start" : "end";
                                            placer.alignLocal = a;                    // snap instantly
                                            chip.x = Qt.binding(function () { return placer.chipX(); });
                                            chip.y = Qt.binding(function () { return placer.chipY(); });
                                            pg.place(detail.sel.id, "framePopout", placer.edge, a, placer.hoverW(), placer.hoverH());
                                        }
                                    }
                                }
                            }

                            // edge selector: a 4-way seg for the docking edge.
                            Seg {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.bottom: parent.bottom
                                options: ["Top", "Right", "Bottom", "Left"]
                                current: placer.edge.charAt(0).toUpperCase() + placer.edge.slice(1)
                                onChose: (label) => pg.place(detail.sel.id, "framePopout",
                                    label.toLowerCase(), placer.align, placer.hoverW(), placer.hoverH())
                            }
                        }

                        // desktop-widget hint: those are placed on the wallpaper.
                        Text {
                            width: parent.width
                            visible: detail.enabled && detail.host === "desktopWidget"
                            text: "Desktop widgets are moved, resized and hidden on the wallpaper. Drag the tile, or right-click it for its menu."
                            color: Tokens.inkMuted; font.family: Tokens.ui
                            font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                        }
                    }

                    // ── Settings: the plugin's own fields, from its schema ──
                    Column {
                        width: parent.width
                        spacing: Tokens.s3
                        visible: detail.schema.length > 0

                        Item {
                            width: parent.width; height: 20
                            Row {
                                id: sHead
                                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                spacing: Tokens.s2
                                Rectangle { width: 4; height: 4; color: Tokens.ink; anchors.verticalCenter: parent.verticalCenter }
                                Text {
                                    text: "SETTINGS"; color: Tokens.ink; font.family: Tokens.ui
                                    font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                                    font.letterSpacing: Tokens.trackMark
                                    anchors.verticalCenter: parent.verticalCenter
                                }
                            }
                            Rectangle {
                                anchors.left: sHead.right; anchors.leftMargin: Tokens.s3
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                height: 1; color: Tokens.lineSoft
                            }
                        }

                        // The settings form: a generic renderer that turns the
                        // plugin's declared schema into native controls. Nothing
                        // here is hardcoded per plugin; the type -> control switch
                        // (default arm = text, so unknown types stay editable) and
                        // a live local value mirror carry every field. Each change
                        // fires setSetting() -> plugins.json.
                        Column {
                            id: form
                            width: parent.width
                            spacing: Tokens.s4

                            property var values: detail.place.settings || ({})
                            property var _local: ({})
                            onValuesChanged: form._local = JSON.parse(JSON.stringify(form.values || {}))
                            Component.onCompleted: form._local = JSON.parse(JSON.stringify(form.values || {}))

                            function _val(field) {
                                if (form._local && form._local[field.key] !== undefined)
                                    return form._local[field.key];
                                return field.default;
                            }
                            function _set(key, value) {
                                var n = JSON.parse(JSON.stringify(form._local || {}));
                                n[key] = value;
                                form._local = n;
                                pg.setSetting(detail.sel.id, key, value);
                            }
                            function _choiceLabel(field, val) {
                                var os = field.options || [];
                                for (var i = 0; i < os.length; i++)
                                    if (String(os[i].value) === String(val))
                                        return os[i].label;
                                return String(val);
                            }
                            function _choiceKeyOf(field, label) {
                                var os = field.options || [];
                                for (var i = 0; i < os.length; i++)
                                    if (os[i].label === label)
                                        return os[i].value;
                                return label;
                            }

                            Repeater {
                                model: detail.schema

                                delegate: Column {
                                    id: fieldWrap
                                    required property var modelData
                                    required property int index
                                    width: form.width
                                    spacing: Tokens.s3

                                    readonly property string grp: modelData.group || ""
                                    readonly property bool startsGroup: fieldWrap.index === 0
                                        || ((detail.schema[fieldWrap.index - 1].group || "") !== fieldWrap.grp)

                                    // group header (grotesk section caps + hairline),
                                    // once per distinct group; blank group = none.
                                    Item {
                                        width: parent.width
                                        height: 16
                                        visible: fieldWrap.startsGroup && fieldWrap.grp.length > 0
                                        Text {
                                            id: gHead
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            text: fieldWrap.grp
                                            color: Tokens.inkMuted; font.family: Tokens.ui
                                            font.pixelSize: Tokens.fMicro; font.weight: Font.Medium
                                            font.letterSpacing: Tokens.trackMark
                                            font.capitalization: Font.AllUppercase
                                        }
                                        Rectangle {
                                            anchors.left: gHead.right; anchors.leftMargin: Tokens.s3
                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: 1; color: Tokens.lineSoft
                                        }
                                    }

                                    Loader {
                                        width: parent.width
                                        sourceComponent: {
                                            switch (fieldWrap.modelData.type) {
                                            case "choice": return cChoice;
                                            case "toggle": return cToggle;
                                            case "slider": return cSlider;
                                            case "image": return cImage;
                                            default: return cText;   // text + anything unknown
                                            }
                                        }
                                        onLoaded: item.field = fieldWrap.modelData
                                    }
                                }
                            }

                            // ── field control templates ──

                            Component {
                                id: cToggle
                                Item {
                                    id: ct
                                    property var field: ({})
                                    width: form.width
                                    implicitHeight: 30
                                    Text {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: ctSw.left; anchors.rightMargin: Tokens.s3
                                        elide: Text.ElideRight
                                        text: ct.field.label || ct.field.key
                                        color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                    }
                                    Sw {
                                        id: ctSw
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        on: form._val(ct.field) === true || form._val(ct.field) === "true"
                                        onToggled: (v) => form._set(ct.field.key, v)
                                    }
                                }
                            }

                            // choice: a seg for <=4 options, a wrapped chip band
                            // for more (both invert the selected member; neither
                            // needs an overlay, so the form stays self-contained).
                            Component {
                                id: cChoice
                                Column {
                                    id: cc
                                    property var field: ({})
                                    width: form.width
                                    spacing: Tokens.s2
                                    readonly property var _labels: (cc.field.options || []).map(function (o) { return o.label; })
                                    readonly property string _curLabel: form._choiceLabel(cc.field, String(form._val(cc.field)))
                                    readonly property bool _few: cc._labels.length <= 4

                                    Item {
                                        visible: cc._few
                                        width: cc.width
                                        height: 30
                                        Text {
                                            anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                            anchors.right: segFew.left; anchors.rightMargin: Tokens.s3
                                            elide: Text.ElideRight
                                            text: cc.field.label || cc.field.key
                                            color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                        }
                                        Seg {
                                            id: segFew
                                            anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                            options: cc._labels
                                            current: cc._curLabel
                                            onChose: (label) => form._set(cc.field.key, form._choiceKeyOf(cc.field, label))
                                        }
                                    }
                                    Text {
                                        visible: !cc._few
                                        width: cc.width
                                        text: cc.field.label || cc.field.key
                                        color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                    }
                                    Chips {
                                        visible: !cc._few
                                        width: cc.width
                                        options: cc._labels
                                        current: cc._curLabel
                                        onChose: (label) => form._set(cc.field.key, form._choiceKeyOf(cc.field, label))
                                    }
                                }
                            }

                            // slider: reuses the integer-domain Slid by mapping the
                            // field's range onto its step count, so decimals and
                            // step survive; the numeral is the live readout.
                            Component {
                                id: cSlider
                                Item {
                                    id: cs
                                    property var field: ({})
                                    width: form.width
                                    implicitHeight: 30
                                    readonly property real _from: cs.field.min !== undefined ? cs.field.min : 0
                                    readonly property real _to: cs.field.max !== undefined ? cs.field.max : 1
                                    readonly property int _dec: cs.field.decimals !== undefined ? cs.field.decimals : 2
                                    readonly property real _step: cs.field.step !== undefined ? cs.field.step : (cs._dec === 0 ? 1 : 0.01)
                                    readonly property real _v: Number(form._val(cs.field))
                                    readonly property int _steps: Math.max(1, Math.round((cs._to - cs._from) / cs._step))

                                    Text {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: csNum.left; anchors.rightMargin: Tokens.s3
                                        elide: Text.ElideRight
                                        text: cs.field.label || cs.field.key
                                        color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                    }
                                    Text {
                                        id: csNum
                                        anchors.right: csTrack.left; anchors.rightMargin: Tokens.s3
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: cs._dec === 0 ? ("" + Math.round(cs._v)) : cs._v.toFixed(cs._dec)
                                        color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                    }
                                    Slid {
                                        id: csTrack
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: 220
                                        from: 0
                                        to: cs._steps
                                        value: Math.round((cs._v - cs._from) / cs._step)
                                        onModified: (iv) => {
                                            var actual = cs._from + iv * cs._step;
                                            form._set(cs.field.key, cs._dec === 0 ? Math.round(actual) : Number(actual.toFixed(cs._dec)));
                                        }
                                    }
                                }
                            }

                            Component {
                                id: cText
                                Item {
                                    id: cx
                                    property var field: ({})
                                    width: form.width
                                    implicitHeight: 30
                                    Text {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: cxBox.left; anchors.rightMargin: Tokens.s3
                                        elide: Text.ElideRight
                                        text: cx.field.label || cx.field.key
                                        color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                    }
                                    Field {
                                        id: cxBox
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: 220
                                        placeholder: cx.field.placeholder || ""
                                        text: String(form._val(cx.field) || "")
                                        // commit on editing-finished only, like every field.
                                        onCommitted: (v) => form._set(cx.field.key, v)
                                    }
                                }
                            }

                            // image: a labelled box that opens the system file
                            // chooser (through the XDG portal); stores a file:// URL.
                            Component {
                                id: cImage
                                Item {
                                    id: ci
                                    property var field: ({})
                                    width: form.width
                                    implicitHeight: 30
                                    readonly property string cur: String(form._val(ci.field) || "")
                                    Text {
                                        anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                                        anchors.right: ciBox.left; anchors.rightMargin: Tokens.s3
                                        elide: Text.ElideRight
                                        text: ci.field.label || ci.field.key
                                        color: Tokens.inkDim; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                                    }
                                    Rectangle {
                                        id: ciBox
                                        anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                                        width: 220; height: 30
                                        radius: Tokens.radius
                                        color: ciHov.hovered ? Tokens.tint10 : "transparent"
                                        border.width: Tokens.border
                                        border.color: ciHov.hovered ? Tokens.lineStrong : Tokens.line
                                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
                                        Text {
                                            anchors.left: parent.left; anchors.leftMargin: 9
                                            anchors.right: parent.right; anchors.rightMargin: 9
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideLeft
                                            text: ci.cur.length === 0 ? "Choose image\u2026" : ci.cur.replace(/^.*\//, "")
                                            color: ci.cur.length === 0 ? Tokens.inkMuted : Tokens.ink
                                            font.family: ci.cur.length === 0 ? Tokens.ui : Tokens.mono
                                            font.pixelSize: ci.cur.length === 0 ? 12 : 11
                                        }
                                        HoverHandler { id: ciHov; cursorShape: Qt.PointingHandCursor }
                                        TapHandler { onTapped: ciDlg.open() }
                                    }
                                    FileDialog {
                                        id: ciDlg
                                        title: "Choose an image"
                                        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp)", "All files (*)"]
                                        onAccepted: form._set(ci.field.key, "" + ciDlg.selectedFile)
                                    }
                                }
                            }
                        }
                    }

                    // sibling empty state, agreeing with the form's own gate.
                    Text {
                        width: parent.width
                        visible: detail.schema.length === 0
                        text: "This add-on has no configurable settings."
                        color: Tokens.inkFaint; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                    }
                }
            }
        }
    }

    // ── destructive confirm: a bone plate, 2px border, an unambiguous verb ──
    // No red anywhere: inversion and the word carry the weight (DESIGN.md
    // sections 1 and 4). The scrim has no fill (translucency is banned); the
    // plate reads as an overlay by being bone on black.
    MouseArea {
        id: confirmScrim
        anchors.fill: parent
        visible: pg.confirmRemove
        z: 100
        onClicked: pg.confirmRemove = false

        Rectangle {
            id: plate
            anchors.centerIn: parent
            width: 380
            height: plateCol.implicitHeight + Tokens.s5 * 2
            radius: Tokens.radius
            color: Tokens.bone
            border.width: 2
            border.color: Tokens.inkOnBone

            // absorb clicks inside the plate so they do not dismiss it.
            MouseArea { anchors.fill: parent }

            Column {
                id: plateCol
                anchors.centerIn: parent
                width: parent.width - Tokens.s5 * 2
                spacing: Tokens.s4

                Text {
                    width: parent.width
                    text: "Remove " + (pg.sel && pg.sel.manifest && pg.sel.manifest.name
                        ? pg.sel.manifest.name : (pg.sel ? pg.sel.id : "add-on")) + "?"
                    color: Tokens.inkOnBone; font.family: Tokens.ui
                    font.pixelSize: Tokens.fValue; font.weight: Font.Medium
                    wrapMode: Text.WordWrap
                }
                Text {
                    width: parent.width
                    text: "This deletes the add-on and its settings from your desktop. You can reinstall it from the Store."
                    color: Tokens.inkOnBoneDim; font.family: Tokens.ui
                    font.pixelSize: Tokens.fSmall; wrapMode: Text.WordWrap
                }
                Row {
                    anchors.right: parent.right
                    spacing: Tokens.s3

                    Rectangle {
                        width: cancelT.implicitWidth + 30; height: 32; radius: Tokens.radius
                        color: cancelH.hovered ? Tokens.lineOnBone : "transparent"
                        border.width: Tokens.border; border.color: Tokens.inkOnBoneDim
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        Text {
                            id: cancelT
                            anchors.centerIn: parent
                            text: "CANCEL"; color: Tokens.inkOnBone
                            font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                        }
                        HoverHandler { id: cancelH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: pg.confirmRemove = false }
                    }
                    // the committed verb: black on bone, inversion within inversion.
                    Rectangle {
                        width: rmT.implicitWidth + 30; height: 32; radius: Tokens.radius
                        color: rmH.hovered ? Tokens.inkOnBoneDim : Tokens.inkOnBone
                        Behavior on color { ColorAnimation { duration: Tokens.snap } }
                        Text {
                            id: rmT
                            anchors.centerIn: parent
                            text: "REMOVE"; color: Tokens.bone
                            font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium; font.letterSpacing: Tokens.trackLabel
                        }
                        HoverHandler { id: rmH; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: pg.removePlugin(pg.selId) }
                    }
                }
            }
        }
    }
}
