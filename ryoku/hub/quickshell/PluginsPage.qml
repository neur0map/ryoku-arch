pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import "Singletons"

/**
 * Plugins: a storefront first, a manager second. The page opens on Discover - a
 * gallery of downloadable plugins, each a card with a live preview that opens a
 * featured detail page (the Profile-style showcase) with an Install action. A
 * segmented switch flips to Installed, where each installed plugin is enabled and
 * placed (host + the frame-popout editor); the running shell retunes live because
 * the plugin runtime watches plugins.json.
 *
 * Catalogue comes from `ryoku-hub extras plugincatalog` (the ryoku-extras repo,
 * cached for offline). Installs go through `ryoku-hub extras plugin <id>`; enable
 * and placement through `ryoku-plugins-place`; the installed list from
 * `discover.sh --all`.
 */
Item {
    id: page

    // Three views: "discover" (store grid), "detail" (one plugin), "installed".
    property string view: "discover"
    property var detailPlugin: ({})

    property var catalog: []      // downloadable plugins (from plugincatalog)
    property var plugins: []      // installed plugins (from discover.sh --all)
    property string busyId: ""    // id currently installing/removing
    property bool refreshing: false
    // Discover-only when embedded in the unified Store: the Installed tab moves to
    // the Add-ons page, so the store just browses and installs.
    property bool storeMode: false

    readonly property string shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string script: (shellDir && shellDir.length > 0)
        ? shellDir + "/quickshell/plugins/discover.sh"
        : (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/quickshell/plugins/discover.sh"

    function isInstalled(id) {
        for (var i = 0; i < page.plugins.length; i++) if (page.plugins[i].id === id) return true;
        return false;
    }
    function refresh() { listProc.running = false; listProc.running = true; }
    function loadCatalog() { catProc.running = false; catProc.running = true; }
    function place(id, field, a, b, c, d) {
        var args = ["ryoku-plugins-place", id, field];
        for (var v of [a, b, c, d]) if (v !== undefined) args.push("" + v);
        placeProc.command = args;
        placeProc.running = true;
    }
    function install(id) {
        page.busyId = id;
        installProc.command = ["ryoku-hub", "extras", "plugin", id];
        installProc.running = true;
    }
    function removePlugin(id) {
        page.busyId = id;
        // Disable it, then remove the data-dir plugin via the symlink-safe backend
        // (a dev plugin is a symlink into the checkout; rm -rf would gut the repo).
        place(id, "enabled", "false");
        rmProc.command = ["ryoku-hub", "extras", "pluginremove", id];
        rmProc.running = true;
    }

    Component.onCompleted: { refresh(); loadCatalog(); }

    Process {
        id: listProc
        command: ["bash", page.script, "--all"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: { try { page.plugins = JSON.parse(text || "[]"); } catch (e) { page.plugins = []; } }
        }
    }
    Process {
        id: catProc
        command: ["ryoku-hub", "extras", "plugincatalog"]
        stdout: StdioCollector {
            onStreamFinished: {
                var list = [];
                try { var o = JSON.parse(text || "{}"); list = o.plugins || []; } catch (e) { list = []; }
                // Fallback so the store is never empty while the remote catalogue is
                // unpopulated/offline: seed the official wallhaven entry from its
                // assets in the plugin data dir (which exists in dev and installed),
                // independent of RYOKU_SHELL_DIR which the hub process may not have.
                if (list.length === 0) {
                    var dataHome = Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share");
                    var base = "file://" + dataHome + "/ryoku/plugins/wallhaven/assets/";
                    list = [{
                        "id": "wallhaven", "name": "Wallhaven", "official": true,
                        "author": "Ryoku Team",
                        "tagline": "Browse wallhaven.cc and set your wallpaper, from any host.",
                        "description": "A full wallpaper browser for the Ryoku desktop. Search wallhaven.cc, filter by Latest / Top week / Top month, page through results, and set any wallpaper with a click. Renders as a frame popout that melts out of the screen edge, or as a draggable desktop widget alongside your clock and weather - the same view, native in either home.",
                        "icon": "wallpaper",
                        "hosts": ["framePopout", "desktopWidget"],
                        "preview": base + "preview-popout.png",
                        "screenshots": [base + "preview-popout.png", base + "preview-widget.png"]
                    }];
                }
                page.catalog = list;
                page.refreshing = false;
            }
        }
    }
    Process { id: placeProc; onExited: page.refresh() }
    Process {
        id: installProc
        onExited: { page.busyId = ""; page.refresh(); }
    }
    Process { id: rmProc; onExited: { page.busyId = ""; page.refresh(); } }

    // Refresh: re-pull the catalogue (so plugins newly added to ryoku-extras show
    // up) and re-scan installed plugins, without leaving the page. Mirrors the
    // lockscreen refresh. Spins while a fetch is in flight.
    Rectangle {
        id: refreshBtn
        visible: page.view !== "detail" && !page.storeMode
        anchors.top: parent.top
        anchors.right: tabs.left
        anchors.rightMargin: 10
        width: 32; height: 32; radius: 9
        color: rHover.hovered ? Theme.surface : "transparent"
        border.width: 1
        border.color: rHover.hovered ? Theme.ember : "transparent"
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
        z: 2
        Icon {
            id: rIcon
            anchors.centerIn: parent
            name: "refresh"
            size: 15
            weight: 2
            tint: rHover.hovered ? Theme.bright : Theme.dim
            RotationAnimation on rotation { running: page.refreshing; loops: Animation.Infinite; from: 0; to: 360; duration: 800 }
        }
        HoverHandler { id: rHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: { page.refreshing = true; page.loadCatalog(); page.refresh(); } }
    }

    // ── Segmented switch: Discover | Installed (hidden on the detail view) ───
    Row {
        id: tabs
        visible: page.view !== "detail" && !page.storeMode
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.rightMargin: 8
        spacing: 0
        z: 2

        Repeater {
            model: [{ k: "discover", l: "Discover" }, { k: "installed", l: "Installed" }]
            delegate: Rectangle {
                id: tab
                required property var modelData
                readonly property bool sel: page.view === tab.modelData.k
                width: tl.implicitWidth + 30; height: 32
                radius: 9
                color: sel ? Theme.surface : "transparent"
                border.width: 1
                border.color: sel ? Theme.line : "transparent"
                Behavior on color { ColorAnimation { duration: Theme.quick } }
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Text {
                        id: tl
                        anchors.verticalCenter: parent.verticalCenter
                        text: tab.modelData.l
                        color: tab.sel ? Theme.bright : Theme.dim
                        font.family: Theme.font; font.pixelSize: 13; font.weight: tab.sel ? Font.DemiBold : Font.Medium
                    }
                    Rectangle {
                        visible: tab.modelData.k === "installed" && page.plugins.length > 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: cnt.implicitWidth + 12; height: 18; radius: 9
                        color: tab.sel ? Theme.ember : Theme.surfaceLo
                        Text { id: cnt; anchors.centerIn: parent; text: "" + page.plugins.length; color: tab.sel ? Theme.onAccent : Theme.dim; font.family: Theme.mono; font.pixelSize: 10; font.weight: Font.DemiBold }
                    }
                }
                TapHandler { onTapped: page.view = tab.modelData.k }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
    }

    // ── Discover: the store grid ────────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        visible: page.view === "discover"
        contentHeight: grid.implicitHeight + 56
        clip: true

        Flow {
            id: grid
            width: parent.width
            spacing: 18
            topPadding: page.storeMode ? 4 : 48

            Repeater {
                model: page.catalog
                delegate: PluginStoreCard {
                    required property var modelData
                    width: Math.max(300, (grid.width - 18 * 2) / 3)
                    plugin: modelData
                    installed: page.isInstalled(modelData.id)
                    onOpened: { page.detailPlugin = modelData; page.view = "detail"; }
                }
            }
        }

        // Empty state.
        Column {
            visible: page.catalog.length === 0
            anchors.centerIn: parent
            spacing: 10
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "sparkles"; size: 34; weight: 1.5; tint: Theme.faint }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "The plugin catalogue is loading, or unreachable."; color: Theme.dim; font.family: Theme.font; font.pixelSize: 13 }
        }
    }

    // ── Detail: the showcase ────────────────────────────────────────────────
    PluginStoreDetail {
        anchors.fill: parent
        visible: page.view === "detail"
        plugin: page.detailPlugin
        installed: page.isInstalled(page.detailPlugin.id || "")
        busy: page.busyId === (page.detailPlugin.id || "_")
        onBack: page.view = "discover"
        onInstall: (id) => page.install(id)
        onRemove: (id) => page.removePlugin(id)
    }

    // ── Installed: enable + place ───────────────────────────────────────────
    Flickable {
        anchors.fill: parent
        visible: page.view === "installed"
        contentHeight: col.implicitHeight + 40
        clip: true

        Column {
            id: col
            width: parent.width
            topPadding: 48
            spacing: 16

            Rectangle {
                width: parent.width
                visible: page.plugins.length === 0
                implicitHeight: 120
                radius: 16
                color: "transparent"
                border.width: 1
                border.color: Theme.line
                Text {
                    anchors.centerIn: parent
                    width: parent.width - 60
                    horizontalAlignment: Text.AlignHCenter
                    text: "No plugins installed yet. Open Discover to browse and install."
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: 13
                    wrapMode: Text.WordWrap
                }
            }

            Repeater {
                model: page.plugins
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    readonly property var man: modelData.manifest
                    readonly property var place: modelData.placement
                    readonly property bool on: place && place.enabled === true
                    readonly property string host: (place && place.host) ? place.host
                        : ((man.defaults && man.defaults.host) ? man.defaults.host : "framePopout")

                    width: col.width
                    implicitHeight: body.implicitHeight + 36
                    radius: 16
                    color: "transparent"
                    border.width: 1
                    border.color: cardHov.hovered ? Theme.ember : Theme.line
                    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
                    HoverHandler { id: cardHov }

                    Column {
                        id: body
                        x: 20; y: 18
                        width: parent.width - 40
                        spacing: 14

                        Item {
                            width: parent.width
                            height: 30
                            Column {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: card.man.name || card.modelData.id
                                    color: Theme.bright
                                    font.family: Theme.font
                                    font.pixelSize: 18
                                    font.weight: Font.DemiBold
                                }
                                Text {
                                    text: (card.man.description || "") + (card.man.official ? "  ·  OFFICIAL" : "")
                                    color: Theme.dim
                                    font.family: Theme.font
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                    width: card.width - 120
                                }
                            }
                            Rectangle {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 46; height: 26; radius: 13
                                color: card.on ? Theme.ember : Theme.surfaceLo
                                border.width: 1
                                border.color: card.on ? Theme.ember : Theme.line
                                Behavior on color { ColorAnimation { duration: Theme.quick } }
                                Rectangle {
                                    width: 20; height: 20; radius: 10; y: 3
                                    x: card.on ? parent.width - width - 3 : 3
                                    color: card.on ? Theme.onAccent : Theme.cream
                                    Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
                                }
                                TapHandler { onTapped: page.place(card.modelData.id, "enabled", card.on ? "false" : "true") }
                                HoverHandler { cursorShape: Qt.PointingHandCursor }
                            }
                        }

                        Item {
                            width: parent.width
                            height: 30
                            visible: card.on
                            Text {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "Show as"
                                color: Theme.cream
                                font.family: Theme.font
                                font.pixelSize: 14
                                font.weight: Font.Medium
                            }
                            Row {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 6
                                Repeater {
                                    model: (card.man.hosts || ["framePopout"]).filter(h => h === "framePopout" || h === "desktopWidget")
                                    delegate: Rectangle {
                                        id: hostCell
                                        required property var modelData
                                        readonly property bool active: card.host === hostCell.modelData
                                        readonly property string nice: hostCell.modelData === "framePopout" ? "Frame popout"
                                            : hostCell.modelData === "desktopWidget" ? "Desktop widget"
                                            : hostCell.modelData
                                        width: hcText.implicitWidth + 22; height: 28; radius: 8
                                        color: active ? Theme.ember : Theme.surfaceLo
                                        border.width: 1
                                        border.color: active ? Theme.ember : Theme.line
                                        Behavior on color { ColorAnimation { duration: Theme.quick } }
                                        Text {
                                            id: hcText
                                            anchors.centerIn: parent
                                            text: hostCell.nice
                                            color: hostCell.active ? Theme.onAccent : Theme.dim
                                            font.family: Theme.font
                                            font.pixelSize: 12
                                            font.weight: hostCell.active ? Font.DemiBold : Font.Medium
                                        }
                                        TapHandler { onTapped: page.place(card.modelData.id, "host", hostCell.modelData) }
                                        HoverHandler { cursorShape: Qt.PointingHandCursor }
                                    }
                                }
                            }
                        }

                        PluginPlacementEditor {
                            width: parent.width
                            visible: card.on && card.host === "framePopout"
                            pluginId: card.modelData.id
                            place: card.place
                            onChanged: (field, args) => page.place(card.modelData.id, field, args[0], args[1], args[2], args[3])
                        }

                        Text {
                            width: parent.width
                            visible: card.on && card.host === "desktopWidget"
                            text: qsTr("Drag the widget on the desktop to place it; right-click it for its menu.")
                            wrapMode: Text.WordWrap
                            color: Theme.dim
                            font.family: Theme.font
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
