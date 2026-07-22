pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Ryoku.Ui
import Ryoku.Ui.Singletons

// Store (DESIGN.md section 8, ADD-ONS). Browse and install shell plugins and
// extras bundles in one place. A Plugins / Bundles switch flips the two
// catalogues; one Refresh re-pulls whichever side is showing. This is a
// full-bleed page: it owns its whole content region, so it draws its own head,
// its own switch and its own actions. Managing what is already installed lives
// on Add-ons, so this only browses and installs.
//
// Backends are reused verbatim: plugins come from `ryoku-hub extras
// plugincatalog` and install via `ryoku-hub extras plugin <id>`; extras bundles
// come from `ryoku-hub extras catalog`, their live status from
// `ryoku-extras-install status`, and install/remove run through
// `ryoku-extras-install` in a floating terminal that streams a per-bundle
// report the detail watches. Nothing writes to disk here except the installers.
//
// Presentation is monochrome per the contract: cards are hairline tiles that
// take the gallery grammar on hover (ink border + a corner dot); the only
// colour is the plugin/bundle preview art, which is a genuine specimen of what
// the add-on looks like. Every token comes from Tokens; nothing is hardcoded.
Item {
    id: pg

    property var hub
    readonly property bool fullBleed: true

    // search text from the rail (the harness passes a bare { query } probe).
    readonly property string query: pg.hub ? (pg.hub.query || "") : ""
    function hit(s) {
        return pg.query === "" || String(s).toLowerCase().indexOf(pg.query.toLowerCase()) >= 0;
    }

    // top split: "plugins" | "bundles". Transient session state, never written.
    property string tab: "plugins"

    // ── plugin store backend (the storeMode half of the old PluginsPage) ─────
    property var catalog: []       // downloadable, from `extras plugincatalog`
    property var installed: []     // installed set, from discover.sh --all
    property string busyId: ""     // plugin id currently installing/removing
    property bool pluginsFetching: false
    property var detailPlugin: ({})
    property bool pluginDetailOpen: false

    readonly property string shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string discoverScript: (pg.shellDir && pg.shellDir.length > 0)
        ? pg.shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/discover.sh"

    function isInstalled(id) {
        for (var i = 0; i < pg.installed.length; i++)
            if (pg.installed[i].id === id)
                return true;
        return false;
    }
    function pluginRefresh() { listProc.running = false; listProc.running = true; }
    function loadCatalog() { catProc.running = false; catProc.running = true; }
    function place(id, field, a, b, c, d) {
        var args = ["ryoku-plugins-place", id, field];
        for (var v of [a, b, c, d]) if (v !== undefined) args.push("" + v);
        placeProc.command = args;
        placeProc.running = true;
    }
    function pluginInstall(id) {
        pg.busyId = id;
        installProc.command = ["ryoku-hub", "extras", "plugin", id];
        installProc.running = true;
    }
    function pluginRemove(id) {
        pg.busyId = id;
        // disable first, then remove the data-dir plugin via the symlink-safe
        // backend (a dev plugin is a symlink into the checkout; rm -rf would gut
        // the repo).
        pg.place(id, "enabled", "false");
        rmProc.command = ["ryoku-hub", "extras", "pluginremove", id];
        rmProc.running = true;
    }

    // catalogue filtered by the rail search.
    readonly property var catalogView: {
        if (pg.query === "")
            return pg.catalog;
        var out = [];
        for (var i = 0; i < pg.catalog.length; i++) {
            var p = pg.catalog[i];
            if (pg.hit((p.name || "") + " " + (p.id || "") + " " + (p.tagline || "") + " " + (p.description || "") + " " + (p.author || "")))
                out.push(p);
        }
        return out;
    }

    // ── extras bundle backend (the old ExtrasPage) ───────────────────────────
    property var bundles: []
    property var statusMap: ({})
    property bool extrasLoading: true
    property bool extrasFailed: false
    property string selectedId: ""

    readonly property string reportDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/ryoku-extras"

    readonly property var selectedBundle: {
        for (var i = 0; i < pg.bundles.length; i++)
            if (pg.bundles[i].id === pg.selectedId)
                return pg.bundles[i];
        return null;
    }

    function extrasReload() {
        pg.extrasLoading = true;
        pg.extrasFailed = false;
        catalogProc.running = true;
    }
    function installedCountFor(id) {
        var m = pg.statusMap[id];
        if (!m)
            return 0;
        var n = 0;
        for (var k in m)
            if (m[k] === "present" || m[k] === "installed") n++;
        return n;
    }
    function runTerminal(args) {
        Quickshell.execDetached(["kitty", "--class", "ryoku-extras", "-e"].concat(args));
    }
    function openBundle(id) { pg.selectedId = id; }
    function closeBundle() { pg.selectedId = ""; statusProc.running = true; }

    readonly property var bundlesView: {
        if (pg.query === "")
            return pg.bundles;
        var out = [];
        for (var i = 0; i < pg.bundles.length; i++) {
            var b = pg.bundles[i];
            if (pg.hit((b.name || "") + " " + (b.id || "") + " " + (b.tagline || "") + " " + (b.description || "") + " " + (b.sources || "")))
                out.push(b);
        }
        return out;
    }

    // Refresh reflects whichever side is in flight, so one control serves both.
    readonly property bool refreshBusy: pg.tab === "plugins" ? pg.pluginsFetching : pg.extrasLoading

    Component.onCompleted: {
        pg.pluginRefresh();
        pg.loadCatalog();
        pg.extrasReload();
    }

    // ── processes: plugins ───────────────────────────────────────────────────
    Process {
        id: listProc
        command: ["bash", pg.discoverScript, "--all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { pg.installed = JSON.parse(text || "[]"); } catch (e) { pg.installed = []; }
            }
        }
    }
    Process {
        id: catProc
        command: ["ryoku-hub", "extras", "plugincatalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = [];
                try { var o = JSON.parse(text || "{}"); list = o.plugins || []; } catch (e) { list = []; }
                // fallback so the store is never empty while the remote catalogue
                // is offline: seed the official wallhaven entry from its assets in
                // the plugin data dir, independent of RYOKU_SHELL_DIR which the hub
                // process may lack.
                if (list.length === 0) {
                    var dataHome = Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share");
                    var base = "file://" + dataHome + "/ryoku/plugins/wallhaven/assets/";
                    list = [{
                        "id": "wallhaven", "name": "Wallhaven", "official": true,
                        "author": "Ryoku Team",
                        "tagline": "Browse wallhaven.cc and set your wallpaper, from any host.",
                        "description": "A full wallpaper browser for the Ryoku desktop. Search wallhaven.cc, filter by Latest / Top week / Top month, page through results, and set any wallpaper with a click. Renders as a frame popout that melts out of the screen edge, or as a draggable desktop widget alongside your clock and weather, the same view, native in either home.",
                        "icon": "wallpaper",
                        "hosts": ["framePopout", "desktopWidget"],
                        "preview": base + "preview-popout.png",
                        "screenshots": [base + "preview-popout.png", base + "preview-widget.png"]
                    }];
                }
                pg.catalog = list;
                pg.pluginsFetching = false;
            }
        }
    }
    Process { id: placeProc; onExited: pg.pluginRefresh() }
    Process { id: installProc; onExited: { pg.busyId = ""; pg.pluginRefresh(); } }
    Process { id: rmProc; onExited: { pg.busyId = ""; pg.pluginRefresh(); } }

    // ── processes: extras ────────────────────────────────────────────────────
    Process {
        id: catalogProc
        command: ["ryoku-hub", "extras", "catalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    var bs = o.bundles || [];
                    pg.bundles = bs;
                    pg.extrasFailed = bs.length === 0;
                } catch (e) {
                    pg.bundles = [];
                    pg.extrasFailed = true;
                }
                pg.extrasLoading = false;
                statusProc.running = true;
            }
        }
    }
    Process {
        id: statusProc
        command: ["ryoku-extras-install", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var o = JSON.parse(this.text);
                    var m = ({});
                    var bs = o.bundles || [];
                    for (var i = 0; i < bs.length; i++) {
                        var im = ({});
                        var its = bs[i].items || [];
                        for (var j = 0; j < its.length; j++)
                            im[its[j].name] = its[j].status;
                        m[bs[i].id] = im;
                    }
                    pg.statusMap = m;
                } catch (e) {
                    pg.statusMap = ({});
                }
            }
        }
    }

    // ── head: eyebrow, Fraunces title, blurb (matches every page) ────────────
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
                text: I18n.tr("ADD-ONS"); color: Tokens.inkMuted; font.family: Tokens.ui
                font.pixelSize: 9; font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                anchors.verticalCenter: parent.verticalCenter
            }
        }
        Text {
            text: I18n.tr("Store"); color: Tokens.ink
            font.family: Tokens.display; font.pixelSize: Tokens.fTitle
        }
        Text {
            width: Math.min(parent.width, 720)
            text: I18n.tr("Browse and install shell plugins and extras bundles. Plugins add live surfaces (frame popouts, desktop widgets); bundles are curated sets of tools that install through a terminal. Managing what is already installed lives on Add-ons.")
            color: Tokens.inkMuted; font.family: Tokens.ui
            font.pixelSize: Tokens.fBody; wrapMode: Text.WordWrap
        }
    }

    // ── action row: the Plugins / Bundles switch, the count, and Refresh ─────
    Item {
        id: bar
        anchors { left: parent.left; right: parent.right; top: head.bottom }
        anchors.leftMargin: Tokens.s6; anchors.rightMargin: Tokens.s6; anchors.topMargin: Tokens.s5
        height: 32

        Tabs {
            id: split
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            options: ["Plugins", "Bundles"]
            current: pg.tab === "plugins" ? "Plugins" : "Bundles"
            onChose: (label) => {
                pg.tab = (label === "Plugins" ? "plugins" : "bundles");
                // leaving a side collapses any detail drill-in it was showing.
                pg.pluginDetailOpen = false;
                pg.selectedId = "";
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.s3

            Text {
                anchors.verticalCenter: parent.verticalCenter
                // an entry count is file-truth chrome, so mono (DESIGN.md section 2).
                readonly property int n: pg.tab === "plugins" ? pg.catalogView.length : pg.bundlesView.length
                text: n + (pg.tab === "plugins"
                           ? (n === 1 ? I18n.tr(" PLUGIN") : I18n.tr(" PLUGINS"))
                           : (n === 1 ? I18n.tr(" BUNDLE") : I18n.tr(" BUNDLES")))
                color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
            Btn {
                anchors.verticalCenter: parent.verticalCenter
                text: pg.refreshBusy ? I18n.tr("REFRESHING") : I18n.tr("REFRESH")
                armed: !pg.refreshBusy
                onAct: {
                    if (pg.tab === "plugins") {
                        pg.pluginsFetching = true;
                        pg.loadCatalog();
                        pg.pluginRefresh();
                    } else {
                        pg.extrasReload();
                    }
                }
            }
        }
    }

    // ── content region ───────────────────────────────────────────────────────
    Item {
        id: content
        anchors {
            left: parent.left; right: parent.right
            top: bar.bottom; bottom: parent.bottom
            leftMargin: Tokens.s6; rightMargin: Tokens.s6
            topMargin: Tokens.s4; bottomMargin: Tokens.s6
        }

        // ── PLUGINS ────────────────────────────────────────────────────────
        Item {
            id: pluginSide
            anchors.fill: parent
            visible: pg.tab === "plugins"

            Flickable {
                id: pluginGrid
                anchors.fill: parent
                visible: !pg.pluginDetailOpen
                contentWidth: width
                contentHeight: pFlow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                Flow {
                    id: pFlow
                    width: pluginGrid.width - Tokens.s3
                    spacing: Tokens.s4

                    Repeater {
                        model: pg.catalogView
                        delegate: StoreCard {
                            required property var modelData
                            width: Math.max(300, (pFlow.width - Tokens.s4 * 2) / 3)
                            art: modelData.preview || ((modelData.screenshots && modelData.screenshots.length > 0) ? modelData.screenshots[0] : "")
                            name: modelData.name || modelData.id || ""
                            blurb: modelData.tagline || modelData.description || ""
                            statusLabel: pg.isInstalled(modelData.id) ? "INSTALLED"
                                : (modelData.official ? "OFFICIAL" : "COMMUNITY")
                            statusStrong: pg.isInstalled(modelData.id) || modelData.official === true
                            chips: (modelData.hosts || []).map(function (h) {
                                return h === "framePopout" ? "Frame popout"
                                     : h === "desktopWidget" ? "Desktop widget" : h;
                            })
                            onOpened: { pg.detailPlugin = modelData; pg.pluginDetailOpen = true; }
                        }
                    }
                }
            }

            // empty / no-match states.
            Column {
                anchors.centerIn: parent
                visible: !pg.pluginDetailOpen && pg.catalogView.length === 0
                spacing: Tokens.s2
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: pg.query !== "" && pg.catalog.length > 0
                        ? I18n.tr("nothing here matches \u201c") + pg.query + "\u201d"
                        : I18n.tr("The plugin catalogue is loading, or unreachable.")
                    color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                }
            }

            // detail drill-in.
            Loader {
                id: pluginDetailLoader
                anchors.fill: parent
                active: pg.pluginDetailOpen
                visible: active
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
                sourceComponent: pluginDetailComp
            }
        }

        // ── BUNDLES ──────────────────────────────────────────────────────────
        Item {
            id: extrasSide
            anchors.fill: parent
            visible: pg.tab === "bundles"

            // loading / failure.
            Column {
                anchors.centerIn: parent
                visible: pg.extrasLoading || pg.extrasFailed
                spacing: Tokens.s4
                width: Math.min(extrasSide.width - Tokens.s7 * 2, 420)

                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: pg.extrasLoading ? I18n.tr("Loading the extras catalogue\u2026") : I18n.tr("Couldn't load the extras catalogue.")
                    color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                }
                Btn {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: pg.extrasFailed
                    text: I18n.tr("TRY AGAIN")
                    onAct: pg.extrasReload()
                }
            }

            Flickable {
                id: extrasGrid
                anchors.fill: parent
                visible: !pg.extrasLoading && !pg.extrasFailed && pg.selectedId === ""
                contentWidth: width
                contentHeight: bFlow.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                Flow {
                    id: bFlow
                    width: extrasGrid.width - Tokens.s3
                    spacing: Tokens.s4

                    Repeater {
                        model: pg.bundlesView
                        delegate: StoreCard {
                            required property var modelData
                            readonly property int installedCount: pg.installedCountFor(modelData.id)
                            readonly property int totalCount: modelData.items ? modelData.items.length : 0
                            readonly property bool allInstalled: totalCount > 0 && installedCount >= totalCount
                            width: Math.max(300, (bFlow.width - Tokens.s4 * 2) / 3)
                            art: modelData.preview || ((modelData.screenshots && modelData.screenshots.length > 0) ? modelData.screenshots[0] : "")
                            name: modelData.name || modelData.id || ""
                            blurb: modelData.tagline || modelData.description || ""
                            statusLabel: allInstalled ? "INSTALLED" : (installedCount + " / " + totalCount)
                            statusStrong: allInstalled
                            statusTabular: !allInstalled
                            chips: {
                                var c = [];
                                if ((modelData.sources || "") !== "") c.push(modelData.sources);
                                c.push(totalCount + " tools");
                                return c;
                            }
                            onOpened: pg.openBundle(modelData.id)
                        }
                    }
                }
            }

            // no-match (catalogue loaded but the search excludes everything).
            Text {
                anchors.centerIn: parent
                visible: !pg.extrasLoading && !pg.extrasFailed && pg.selectedId === "" && pg.bundlesView.length === 0
                text: I18n.tr("nothing here matches \u201c") + pg.query + "\u201d"
                color: Tokens.inkMuted; font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
            }

            // detail drill-in.
            Loader {
                id: bundleDetailLoader
                anchors.fill: parent
                active: pg.selectedId !== "" && pg.selectedBundle !== null
                visible: active
                opacity: visible ? 1 : 0
                Behavior on opacity { NumberAnimation { duration: Tokens.swap; easing.type: Tokens.ease } }
                sourceComponent: bundleDetailComp
            }
        }
    }

    // ── a hairline chip: a status tag or a host name ─────────────────────────
    component Tag: Rectangle {
        property string label: ""
        property bool tabular: false   // mono, for counts and versions
        property bool caps: false      // tracked uppercase, for status labels
        property color fg: Tokens.inkMuted
        implicitWidth: tt.implicitWidth + Tokens.s3
        implicitHeight: 20
        radius: Tokens.radius
        color: "transparent"
        border.width: Tokens.border
        border.color: Tokens.line
        Text {
            id: tt
            anchors.centerIn: parent
            text: I18n.tr(parent.label)
            color: parent.fg
            font.family: parent.tabular ? Tokens.mono : Tokens.ui
            font.pixelSize: parent.tabular ? Tokens.fTiny : 10
            font.weight: Font.Medium
            font.letterSpacing: parent.caps ? Tokens.trackLabel : 0
            font.capitalization: parent.caps ? Font.AllUppercase : Font.MixedCase
        }
    }

    // ── the catalogue tile, shared by plugins and bundles ────────────────────
    // A hairline card carrying the add-on's own preview art on top and its name,
    // status and chips below on black. Hover takes the gallery grammar: the
    // border goes to solid ink and a corner dot appears, the monochrome way a
    // tile says "this one". No scrim, no lift, no shadow.
    component StoreCard: Rectangle {
        id: tile
        property string art: ""
        property string name: ""
        property string blurb: ""
        property string statusLabel: ""
        property bool statusStrong: false
        property bool statusTabular: false
        property var chips: []
        signal opened()

        readonly property int artH: 140
        implicitHeight: artH + 1 + Tokens.s4 + info.implicitHeight + Tokens.s4
        radius: Tokens.radius
        color: th.hovered ? Tokens.tint10 : "transparent"
        border.width: Tokens.border
        border.color: th.hovered ? Tokens.ink : Tokens.line
        clip: true
        Behavior on color { ColorAnimation { duration: Tokens.snap } }
        Behavior on border.color { ColorAnimation { duration: Tokens.snap } }

        // preview art, a genuine specimen so it keeps its own colour.
        Rectangle {
            id: artBox
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: tile.artH
            color: Tokens.paperLift
            clip: true
            Image {
                id: shot
                anchors.fill: parent
                source: tile.art
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                cache: true
                sourceSize.width: 720
                visible: status === Image.Ready
            }
            Text {
                anchors.centerIn: parent
                visible: shot.status !== Image.Ready
                text: "力"; color: Tokens.inkFaint; font.family: Tokens.jp; font.pixelSize: 30
            }
        }
        Rectangle {
            id: artRule
            anchors { left: parent.left; right: parent.right; top: artBox.bottom }
            height: 1; color: Tokens.line
        }

        Column {
            id: info
            anchors { left: parent.left; right: parent.right; top: artRule.bottom }
            anchors.leftMargin: Tokens.s4; anchors.rightMargin: Tokens.s4; anchors.topMargin: Tokens.s4
            spacing: Tokens.s2

            Text {
                width: parent.width
                text: tile.name
                color: Tokens.ink
                font.family: Tokens.ui; font.pixelSize: Tokens.fRow; font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Tag {
                label: tile.statusLabel
                caps: !tile.statusTabular
                tabular: tile.statusTabular
                fg: tile.statusStrong ? Tokens.inkDim : Tokens.inkFaint
            }
            Text {
                width: parent.width
                height: Tokens.s5 + Tokens.s3   // reserve two lines so the grid packs evenly
                text: tile.blurb
                color: Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                wrapMode: Text.WordWrap; maximumLineCount: 2; elide: Text.ElideRight
            }
            Row {
                spacing: Tokens.s2
                Repeater {
                    model: tile.chips
                    delegate: Tag {
                        required property var modelData
                        label: modelData
                        fg: Tokens.inkMuted
                    }
                }
            }
        }

        // gallery corner dot: the ink pip that marks the pointed tile.
        Text {
            visible: th.hovered
            anchors { right: parent.right; bottom: parent.bottom; rightMargin: Tokens.s3; bottomMargin: Tokens.s2 }
            text: "\u25cf"; color: Tokens.ink; font.pixelSize: 7
            z: 2
        }

        HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tile.opened() }
    }

    // ── one tool inside a bundle: status pip, name + summary, single action ──
    component ItemRow: Item {
        id: row
        property string itemName: ""
        property string summary: ""
        property string itemType: "package"
        property string source: ""
        property string status: "absent"
        property string reason: ""
        signal install()
        signal remove()

        readonly property bool busy: status === "installing" || status === "removing"
        readonly property bool here: status === "present" || status === "installed"
        readonly property bool failed: status === "failed"

        implicitHeight: Tokens.rowH
        width: parent ? parent.width : 0

        // pip: filled ink when here, hollow otherwise. Failure carries no colour;
        // the reason line beneath says the word, per the no-red rule.
        Item {
            id: ind
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 18; height: 18
            Text {
                anchors.centerIn: parent
                visible: row.here
                text: "\u2713"; color: Tokens.ink; font.family: Tokens.ui; font.pixelSize: 13; font.weight: Font.Bold
            }
            Rectangle {
                anchors.centerIn: parent
                visible: !row.here
                width: 6; height: 6; radius: 3
                color: "transparent"
                border.width: Tokens.border
                border.color: row.failed ? Tokens.inkDim : Tokens.inkFaint
            }
        }

        Column {
            anchors.left: ind.right
            anchors.leftMargin: Tokens.s3
            anchors.right: actionArea.left
            anchors.rightMargin: Tokens.s3
            anchors.verticalCenter: parent.verticalCenter
                spacing: Tokens.s1

            Row {
                spacing: Tokens.s2
                Text {
                    // a package/tool name is file-truth, so mono.
                    text: row.itemName
                    color: Tokens.ink
                    font.family: Tokens.mono; font.pixelSize: Tokens.fSmall; font.weight: Font.DemiBold
                }
                Text {
                    visible: row.source !== ""
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.source
                    color: Tokens.inkFaint
                    font.family: Tokens.mono; font.pixelSize: Tokens.fTiny; font.weight: Font.DemiBold
                }
            }
            Text {
                width: parent.width
                text: row.failed && row.reason !== "" ? row.reason : row.summary
                color: row.failed ? Tokens.inkDim : Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                elide: Text.ElideRight
            }
        }

        Item {
            id: actionArea
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 96; height: 30

            // scripts are never auto-removed and plugins live on Add-ons, so a
            // deferred item shows a quiet note instead of a button.
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.status === "deferred"
                text: row.itemType === "plugin" ? "Plugins" : I18n.tr("Manual")
                color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: row.busy
                text: I18n.tr("WORKING")
                color: Tokens.inkFaint; font.family: Tokens.mono; font.pixelSize: Tokens.fTiny
            }
            Btn {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.busy && !row.here && row.status !== "deferred"
                text: row.failed ? I18n.tr("RETRY") : I18n.tr("INSTALL")
                onAct: row.install()
            }
            Btn {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !row.busy && row.here && (row.itemType === "package" || row.itemType === "nautilus-pack")
                // remove is not danger and there is no red on the sheet to carry
                // one; the verb is unambiguous on its own.
                text: I18n.tr("REMOVE")
                onAct: row.remove()
            }
        }

        Rectangle {
            anchors { left: ind.right; leftMargin: Tokens.s3; right: parent.right; bottom: parent.bottom }
            height: 1; color: Tokens.lineSoft
        }
    }

    // ── the plugin detail: a showcase drill-in ───────────────────────────────
    Component {
        id: pluginDetailComp

        Item {
            id: detail
            readonly property var plugin: pg.detailPlugin
            readonly property bool installed: pg.isInstalled(pg.detailPlugin.id || "")
            readonly property bool busy: pg.busyId === (pg.detailPlugin.id || "_")

            readonly property var shots: {
                var s = [];
                if (detail.plugin.preview) s.push(detail.plugin.preview);
                var ss = detail.plugin.screenshots || [];
                for (var i = 0; i < ss.length; i++)
                    if (ss[i] !== detail.plugin.preview) s.push(ss[i]);
                return s;
            }
            property int shotIndex: 0
            readonly property string hero: detail.shots.length > 0
                ? detail.shots[Math.min(detail.shotIndex, detail.shots.length - 1)] : ""

            Btn {
                id: backBtn
                anchors { left: parent.left; top: parent.top }
                text: I18n.tr("\u2039  STORE")
                onAct: pg.pluginDetailOpen = false
            }

            Item {
                id: body
                anchors {
                    left: parent.left; right: parent.right
                    top: backBtn.bottom; bottom: parent.bottom
                    topMargin: Tokens.s5
                }
                readonly property real heroW: Math.round(Math.min(width * 0.52, 600))

                // hero art + screenshot strip.
                Column {
                    id: heroCol
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: body.heroW
                    spacing: Tokens.s3

                    Rectangle {
                        id: heroFrame
                        width: parent.width
                        height: parent.height - (detail.shots.length > 1 ? 94 : 0)
                        radius: Tokens.radius
                        color: Tokens.paperLift
                        border.width: Tokens.border
                        border.color: Tokens.line
                        clip: true
                        Image {
                            id: heroImg
                            anchors.fill: parent; anchors.margins: Tokens.border
                            source: detail.hero
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true; cache: true
                            sourceSize.width: 1400
                            visible: status === Image.Ready
                            Behavior on opacity { NumberAnimation { duration: Tokens.swap } }
                        }
                        Text {
                            anchors.centerIn: parent
                            visible: heroImg.status !== Image.Ready
                            text: "力"; color: Tokens.inkFaint; font.family: Tokens.jp; font.pixelSize: 44
                        }
                    }

                    // strip: gallery grammar again, the selected thumb takes the
                    // ink border and a corner dot.
                    Row {
                        visible: detail.shots.length > 1
                        spacing: Tokens.s2
                        Repeater {
                            model: detail.shots
                            delegate: Rectangle {
                                id: thumb
                                required property int index
                                required property var modelData
                                readonly property bool sel: detail.shotIndex === index
                                width: 124; height: 78; radius: Tokens.radius
                                color: sel ? Tokens.tint10 : (thHov.hovered ? Tokens.tint5 : "transparent")
                                border.width: Tokens.border
                                border.color: sel ? Tokens.ink : (thHov.hovered ? Tokens.lineStrong : Tokens.line)
                                clip: true
                                Behavior on border.color { ColorAnimation { duration: Tokens.snap } }
                                Behavior on color { ColorAnimation { duration: Tokens.snap } }
                                Image {
                                    anchors.fill: parent; anchors.margins: Tokens.border
                                    source: thumb.modelData
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true; cache: true
                                    sourceSize.width: 280
                                }
                                Text {
                                    visible: thumb.sel
                                    anchors { right: parent.right; bottom: parent.bottom; rightMargin: Tokens.s2; bottomMargin: Tokens.s1 }
                                    text: "\u25cf"; color: Tokens.ink; font.pixelSize: 7
                                }
                                HoverHandler { id: thHov; cursorShape: Qt.PointingHandCursor }
                                TapHandler { onTapped: detail.shotIndex = thumb.index }
                            }
                        }
                    }
                }

                // dossier.
                Flickable {
                    id: dossier
                    anchors {
                        left: heroCol.right; leftMargin: Tokens.s6
                        right: parent.right
                        top: parent.top; bottom: parent.bottom
                    }
                    contentWidth: width
                    contentHeight: col.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                    Column {
                        id: col
                        width: dossier.width - Tokens.s3
                        spacing: Tokens.s3

                        Row {
                            spacing: Tokens.s2
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "力"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: 20
                            }
                            Tag {
                                anchors.verticalCenter: parent.verticalCenter
                                label: detail.plugin.official ? I18n.tr("OFFICIAL") : I18n.tr("COMMUNITY")
                                caps: true
                                fg: detail.plugin.official ? Tokens.inkDim : Tokens.inkFaint
                            }
                        }

                        Text {
                            width: parent.width
                            text: detail.plugin.name || detail.plugin.id || ""
                            color: Tokens.ink
                            font.family: Tokens.ui; font.pixelSize: Tokens.fHero; font.weight: Font.Light
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            width: parent.width
                            visible: (detail.plugin.tagline || "") !== ""
                            text: detail.plugin.tagline || ""
                            color: Tokens.inkDim
                            font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                            wrapMode: Text.WordWrap
                        }
                        Text {
                            visible: (detail.plugin.author || "") !== ""
                            text: detail.plugin.author ? ("by " + detail.plugin.author) : ""
                            color: Tokens.inkMuted
                            font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                        }

                        // install / remove.
                        Row {
                            topPadding: Tokens.s1
                            spacing: Tokens.s2
                            Btn {
                                text: detail.busy ? I18n.tr("WORKING") : (detail.installed ? I18n.tr("INSTALLED") : I18n.tr("INSTALL"))
                                primary: !detail.installed && !detail.busy
                                armed: !detail.installed && !detail.busy
                                onAct: pg.pluginInstall(detail.plugin.id)
                            }
                            Btn {
                                visible: detail.installed && !detail.busy
                                text: I18n.tr("REMOVE")
                                onAct: pg.pluginRemove(detail.plugin.id)
                            }
                        }

                        Rectangle { width: parent.width; height: 1; color: Tokens.lineSoft }

                        Text {
                            width: parent.width
                            text: detail.plugin.description || detail.plugin.tagline || ""
                            color: Tokens.inkMuted
                            font.family: Tokens.ui; font.pixelSize: Tokens.fBody
                            lineHeight: 1.4
                            wrapMode: Text.WordWrap
                        }

                        Text {
                            visible: (detail.plugin.hosts || []).length > 0
                            text: I18n.tr("PLACES WHERE IT LIVES")
                            color: Tokens.inkMuted
                            font.family: Tokens.ui; font.pixelSize: Tokens.fMicro
                            font.weight: Font.Medium; font.letterSpacing: Tokens.trackMark
                        }
                        Flow {
                            width: parent.width
                            spacing: Tokens.s2
                            Repeater {
                                model: detail.plugin.hosts || []
                                delegate: Tag {
                                    required property var modelData
                                    label: modelData === "framePopout" ? I18n.tr("Frame popout")
                                        : modelData === "desktopWidget" ? I18n.tr("Desktop widget") : modelData
                                    fg: Tokens.inkDim
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // ── the bundle detail: hero banner, install-all, and the tool list ───────
    Component {
        id: bundleDetailComp

        Item {
            id: bdetail
            readonly property var bundle: pg.selectedBundle || ({})
            readonly property var statuses: pg.statusMap[pg.selectedId] || ({})
            readonly property var items: bundle.items || []

            // steady state comes from `statuses`; while an install or remove
            // started here is running, the live report file wins until the page
            // hands back a fresh status.
            property bool armed: false
            property var live: ({})
            onStatusesChanged: { bdetail.armed = false; bdetail.live = ({}); }

            function effStatus(name) {
                if (bdetail.armed && bdetail.live[name])
                    return bdetail.live[name].status;
                if (bdetail.statuses[name] !== undefined)
                    return bdetail.statuses[name];
                return "absent";
            }
            function effReason(name) {
                return (bdetail.armed && bdetail.live[name]) ? (bdetail.live[name].reason || "") : "";
            }
            function isHere(s) { return s === "present" || s === "installed"; }
            function arm() { bdetail.armed = true; }

            readonly property int installedCount: {
                var n = 0;
                for (var i = 0; i < items.length; i++)
                    if (isHere(effStatus(items[i].name))) n++;
                return n;
            }
            readonly property bool anyPackagePresent: {
                for (var i = 0; i < items.length; i++)
                    if (items[i].type === "package" && isHere(effStatus(items[i].name))) return true;
                return false;
            }

            function applyReport(t) {
                try {
                    var o = JSON.parse(t);
                    bdetail.live = o.items || ({});
                    if (o.phase === "done" && bdetail.armed)
                        statusProc.running = true;
                } catch (e) {}
            }

            FileView {
                id: report
                path: pg.reportDir + "/" + (bdetail.bundle.id || "_") + ".json"
                watchChanges: true
                // the report is written by the installer terminal at install time,
                // so a missing file before then is state, not an error (matches
                // every watched FileView in the Hub).
                printErrors: false
                onLoaded: bdetail.applyReport(report.text())
                onFileChanged: report.reload()
                onLoadFailed: {}
            }

            Btn {
                id: bbackBtn
                anchors { left: parent.left; top: parent.top }
                text: I18n.tr("\u2039  ALL BUNDLES")
                onAct: pg.closeBundle()
            }

            // hero banner: preview art (a specimen) under a hairline frame. No
            // text sits on the art, so nothing needs a scrim or a plate.
            Rectangle {
                id: hero
                anchors { left: parent.left; right: parent.right; top: bbackBtn.bottom; topMargin: Tokens.s4 }
                height: 176
                radius: Tokens.radius
                color: Tokens.paperLift
                border.width: Tokens.border
                border.color: Tokens.line
                clip: true

                Image {
                    id: heroImg
                    anchors.fill: parent; anchors.margins: Tokens.border
                    source: bdetail.bundle.preview || ((bdetail.bundle.screenshots && bdetail.bundle.screenshots.length > 0) ? bdetail.bundle.screenshots[0] : "")
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true; cache: true
                    sourceSize.width: 1200
                    visible: status === Image.Ready
                }
                Text {
                    anchors.centerIn: parent
                    visible: heroImg.status !== Image.Ready
                    text: "力"; color: Tokens.inkFaint; font.family: Tokens.jp; font.pixelSize: 44
                }
            }

            // name + install-all / uninstall-all.
            Item {
                id: bhead
                anchors { left: parent.left; right: parent.right; top: hero.bottom; topMargin: Tokens.s4 }
                height: 34

                Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s2
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "力"; color: Tokens.ink; font.family: Tokens.jp; font.pixelSize: 20
                    }
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bdetail.bundle.name || ""
                        color: Tokens.ink
                        font.family: Tokens.ui; font.pixelSize: Tokens.fValue; font.weight: Font.Light
                    }
                }
                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Tokens.s3
                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: bdetail.installedCount + " / " + bdetail.items.length
                        color: Tokens.inkMuted; font.family: Tokens.mono; font.pixelSize: Tokens.fSmall
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: bdetail.anyPackagePresent
                        text: I18n.tr("UNINSTALL ALL")
                        onAct: { bdetail.arm(); pg.runTerminal(["ryoku-extras-install", "remove", "bundle", pg.selectedId]); }
                    }
                    Btn {
                        anchors.verticalCenter: parent.verticalCenter
                        text: I18n.tr("INSTALL ALL")
                        primary: true
                        onAct: { bdetail.arm(); pg.runTerminal(["ryoku-extras-install", "install", "bundle", pg.selectedId]); }
                    }
                }
            }

            // sources eyebrow: package origins are file-truth, so mono caps.
            Text {
                id: bsrc
                anchors { left: parent.left; top: bhead.bottom; topMargin: Tokens.s3 }
                visible: (bdetail.bundle.sources || "") !== ""
                text: bdetail.bundle.sources || ""
                color: Tokens.inkFaint
                font.family: Tokens.mono; font.pixelSize: Tokens.fMicro
                font.weight: Font.DemiBold; font.capitalization: Font.AllUppercase
            }

            Text {
                id: btag
                anchors { left: parent.left; right: parent.right; top: bsrc.visible ? bsrc.bottom : bhead.bottom; topMargin: Tokens.s3 }
                visible: (bdetail.bundle.tagline || "") !== ""
                text: bdetail.bundle.tagline || ""
                color: Tokens.inkDim
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall; font.weight: Font.Medium
                elide: Text.ElideRight
            }
            Text {
                id: bblurb
                anchors { left: parent.left; right: parent.right; top: btag.visible ? btag.bottom : (bsrc.visible ? bsrc.bottom : bhead.bottom); topMargin: Tokens.s2 }
                text: bdetail.bundle.description || ""
                color: Tokens.inkMuted
                font.family: Tokens.ui; font.pixelSize: Tokens.fSmall
                wrapMode: Text.WordWrap; lineHeight: 1.3
            }
            Rectangle {
                id: brule
                anchors { left: parent.left; right: parent.right; top: bblurb.bottom; topMargin: Tokens.s3 }
                height: 1; color: Tokens.line
            }

            Flickable {
                id: itemFlick
                anchors { left: parent.left; right: parent.right; top: brule.bottom; bottom: parent.bottom; topMargin: Tokens.s1 }
                contentWidth: width
                contentHeight: icol.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                ScrollBar.vertical: ScrollRail { policy: ScrollBar.AsNeeded }

                Column {
                    id: icol
                    width: itemFlick.width - Tokens.s3
                    bottomPadding: Tokens.s4
                    Repeater {
                        model: bdetail.items
                        delegate: ItemRow {
                            required property var modelData
                            width: icol.width
                            itemName: modelData.name
                            summary: modelData.summary || ""
                            itemType: modelData.type
                            source: modelData.source || ""
                            status: bdetail.effStatus(modelData.name)
                            reason: bdetail.effReason(modelData.name)
                            onInstall: { bdetail.arm(); pg.runTerminal(["ryoku-extras-install", "install", "item", pg.selectedId, modelData.name]); }
                            onRemove: { bdetail.arm(); pg.runTerminal(["ryoku-extras-install", "remove", "item", pg.selectedId, modelData.name]); }
                        }
                    }
                }
            }
        }
    }
}
