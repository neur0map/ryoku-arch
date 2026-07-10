pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../Singletons"

// the LEFT sidebar's content: FEATURES. a compact eyebrow header over a
// data-driven tab rail whose enabled panes come from `panes` (Config-driven,
// display order honoured), each tab swapping the lower content between the Stash
// file board, the screen-capture Tools strip, and a Clipboard placeholder. a
// bare, transparent Item -- the shell Popout's blob behind it IS the surface and
// owns the melt/reveal; this panel just fills it. `open` + `effectivePane` gate
// the live work so a hidden pane (and a shut sidebar) costs nothing.
Item {
    id: root

    property real s: 1
    property bool open: false
    // full-span sidebar: the blob fills the frame top-to-bottom, so these insets
    // push the content clear of a top bar and the bottom frame.
    property real topInset: 20 * s
    property real botInset: 20 * s

    // enabled pane keys in display order (from Config), plus the current pane
    // (set by the shell). a tab tap emits paneSelected; the shell writes the
    // chosen key back into `pane`.
    property var panes: []
    property string pane: ""
    signal paneSelected(string key)

    // true while a file drag is over the drop-accepting pane (the stash board),
    // so the shell can keep the sidebar open through a drag mid-grab.
    readonly property bool dragActive: deckStash.dragActive && root.effectivePane === "stash"

    anchors.fill: parent
    implicitWidth: 340 * s

    // sidebarLeft guest panes: plugins that declare host "sidebarLeft" mount
    // here beside Stash. discovered like PluginPopouts (discover.sh +
    // plugins.json watch), so an install/removal retunes the rail live.
    property var guestPanes: []
    readonly property string _shellDir: Quickshell.env("RYOKU_SHELL_DIR")
    readonly property string _script: (_shellDir && _shellDir.length > 0)
        ? _shellDir + "/quickshell/plugins/discover.sh"
        : Quickshell.env("HOME") + "/.local/share/ryoku/quickshell/plugins/discover.sh"
    function reloadGuests() { discoverProc.running = false; discoverProc.running = true; }

    Process {
        id: discoverProc
        command: ["bash", root._script]
        running: true
        stdout: StdioCollector {
            onStreamFinished: {
                var all = [];
                try { all = JSON.parse(text || "[]"); } catch (e) { all = []; }
                root.guestPanes = all
                    .filter(p => p.placement && p.placement.host === "sidebarLeft")
                    .map(p => ({
                        key: p.id,
                        glyph: (p.manifest && p.manifest.defaults && p.manifest.defaults.icon) || "extension",
                        label: (p.manifest && p.manifest.defaults && p.manifest.defaults.label) || p.id,
                        order: (p.placement.sidebarLeft && p.placement.sidebarLeft.order) || 50,
                        dir: p.dir,
                        contentUrl: (p.manifest && p.manifest.entryPoints && p.manifest.entryPoints.content) || "content/Widget.qml",
                        settings: p.placement.settings || ({})
                    }))
                    .sort((a, b) => a.order - b.order);
            }
        }
    }
    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/plugins.json"
        watchChanges: true
        printErrors: false
        onFileChanged: root.reloadGuests()
    }

    // the feature catalog: every pane this side knows how to show, keyed. tabs
    // are the enabled `panes` mapped over it -- unknown keys dropped, order kept.
    readonly property var builtins: [ { "key": "stash", "glyph": "inventory_2" } ]
    readonly property var catalog: root.builtins.concat(
        root.guestPanes.map(g => ({ "key": g.key, "glyph": g.glyph })))
    readonly property var catalogByKey: {
        var m = ({});
        for (var i = 0; i < root.catalog.length; ++i)
            m[root.catalog[i].key] = root.catalog[i];
        return m;
    }
    readonly property var tabs: (root.panes && root.panes.length > 0)
        ? root.panes.map(k => root.catalogByKey[k]).filter(Boolean)
        : root.catalog
    // with only one enabled pane there is nothing to switch, so the tab rail and
    // its divider fold away and the pane fills straight under the eyebrow.
    readonly property bool showRail: root.tabs.length > 1

    // the pane actually shown: the requested `pane` when it's an enabled tab,
    // else the first enabled tab (or nothing when no panes are enabled).
    readonly property string effectivePane: {
        var t = root.tabs;
        for (var i = 0; i < t.length; ++i)
            if (t[i].key === root.pane)
                return root.pane;
        return t.length > 0 ? t[0].key : "";
    }

    component Divider: Rectangle {
        width: parent ? parent.width : 0
        height: 1
        color: Theme.hair
    }

    // tab-rail button: a Material glyph that fills and lights, with an accent
    // underline, when its pane is the one showing. a tap asks the shell to swap.
    component Tab: Item {
        id: tb
        property string glyph: ""
        property string key: ""
        readonly property bool sel: root.effectivePane === tb.key
        height: 40 * root.s
        MaterialIcon {
            anchors.centerIn: parent
            text: tb.glyph
            fill: tb.sel ? 1 : 0
            color: tb.sel ? Theme.brand : (tbHov.hovered ? Theme.cream : Theme.iconDim)
            font.pixelSize: 20 * root.s
            Behavior on color { ColorAnimation { duration: Motion.fast } }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            width: 16 * root.s
            height: 2 * root.s
            radius: Theme.radius
            color: Theme.brand
            visible: tb.sel
        }
        HoverHandler { id: tbHov; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: root.paneSelected(tb.key) }
    }

    // ── header: the Features eyebrow, clock-free ───────────────────────────
    Column {
        id: head
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.topInset
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        spacing: 14 * root.s

        Eyebrow { label: "Features"; s: root.s }
    }

    // ── tab rail: swap the content pane below ───────────────────────────────
    Row {
        id: tabRail
        visible: root.showRail
        anchors.top: head.bottom
        anchors.topMargin: 14 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        readonly property real tabW: root.tabs.length > 0 ? width / root.tabs.length : width
        Repeater {
            model: root.tabs
            delegate: Tab {
                required property var modelData
                width: tabRail.tabW
                glyph: modelData.glyph
                key: modelData.key
            }
        }
    }

    Divider {
        id: railDiv
        visible: root.showRail
        anchors.top: tabRail.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
    }

    // ── content area: the selected pane fills the rest ─────────────────────
    Item {
        id: content
        anchors.top: root.showRail ? railDiv.bottom : head.bottom
        anchors.topMargin: 14 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 18 * root.s
        anchors.rightMargin: 18 * root.s
        anchors.bottomMargin: root.botInset

        // ── stash: the ~/Downloads/Stash file board + LocalSend hub ─────────
        // DeckStash has a fixed implicitHeight but flexes its grid when given a
        // bottom anchor, so anchor it top-to-bottom to fill the pane height.
        Item {
            anchors.fill: parent
            visible: root.effectivePane === "stash"

            MicroLabel {
                id: stashLbl
                anchors.top: parent.top
                anchors.left: parent.left
                label: "Stash"
                s: root.s
            }
            DeckStash {
                id: deckStash
                anchors.top: stashLbl.bottom
                anchors.topMargin: 12 * root.s
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                s: root.s
                active: root.open && root.effectivePane === "stash"
                onRequestClose: {}
            }
        }

        Repeater {
            model: root.guestPanes
            delegate: Item {
                id: guestPane
                required property var modelData
                anchors.fill: parent
                visible: root.effectivePane === modelData.key
                property var api: QtObject {
                    property var mainInstance: guestSvc.item
                    property var pluginSettings: guestPane.modelData.settings
                    property string pluginDir: guestPane.modelData.dir
                    function saveSettings() {}
                }
                Loader {
                    id: guestSvc
                    source: "file://" + guestPane.modelData.dir + "/service/Main.qml"
                    onLoaded: if (item) item.pluginApi = guestPane.api
                }
                Loader {
                    anchors.fill: parent
                    source: "file://" + guestPane.modelData.dir + "/" + guestPane.modelData.contentUrl
                    onLoaded: {
                        if (!item) return;
                        item.pluginApi = guestPane.api;
                        item.density = "full";
                        item.s = root.s;
                        item.widthBudget = width;
                        item.active = Qt.binding(() => root.open && root.effectivePane === guestPane.modelData.key);
                    }
                }
            }
        }
    }
}
