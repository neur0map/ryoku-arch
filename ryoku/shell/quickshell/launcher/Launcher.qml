import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "Singletons"
import "providers"

// The command palette body: a search row over the rest dashboard (empty query),
// the all-apps grid (Ctrl+A from rest), the action-mode tabs + list ("/" prefix),
// or the ranked result list. Ctrl+K opens the selected row's action panel. Grows
// and shrinks with its content on the Ryoku morph curve. Providers register with
// the dispatcher; this view only renders what the dispatcher returns.
Item {
    id: root

    property real s: 1
    property bool shown: false
    property string query: ""
    property bool allApps: false

    signal requestClose()

    readonly property var results: shown ? Dispatcher.results(query, Metrics.maxResults) : []
    readonly property int totalCount: shown ? Dispatcher.results("", 0).length : 0
    readonly property bool resting: query.length === 0
    readonly property bool gridMode: resting && allApps

    // active media player for the rest-state now-playing card.
    readonly property var activePlayer: {
        var list = Mpris.players.values;
        if (!list || list.length === 0)
            return null;
        for (var i = 0; i < list.length; i++)
            if (list[i] && list[i].isPlaying)
                return list[i];
        for (var j = 0; j < list.length; j++)
            if (list[j] && list[j].canControl && list[j].trackTitle)
                return list[j];
        return list[0];
    }
    readonly property bool hasMedia: activePlayer !== null
    // route the current query once; everything keys off the matched prefix so the
    // mode chip, the tabs, and the find delegation stay consistent.
    readonly property var routed: Dispatcher.route(query)
    readonly property string modeLabel: {
        var p = routed.prefix;
        if (p === "/file") return "FILE";
        if (p === "/folder") return "FOLDER";
        if (p === "/image") return "IMAGE";
        if (p === "/video") return "VIDEO";
        if (p === "/") return "ACTIONS";
        if (p === ">") return "PACKAGE";
        if (p === "=") return "CALC";
        if (p === ";") return "CLIPBOARD";
        if (p === "s:") return "SPOTIFY";
        if (p === "@") return "YT MUSIC";
        if (p === "?") return "WEB";
        return "";
    }
    readonly property bool actionMode: routed.provider === "actions"
    // tabs + hint row are browsing aids: show them only for a bare "/" (the
    // action catalog), not once the user types "/play" — then the results take
    // the space and nothing clips.
    readonly property bool actionBrowse: actionMode && routed.query.length === 0
    // an async provider is resolving the current query and nothing has come back
    // yet: show a spinner, not a premature "No matches".
    readonly property bool searching: shown && !resting && Dispatcher.busy && results.length === 0
    readonly property var selectedActions: {
        var r = root.results[list.selectedIndex];
        return r && r.actions ? r.actions : [];
    }

    readonly property real cardW: Metrics.windowW * s
    readonly property int visibleRows: 8
    readonly property real listH: Math.min(results.length, visibleRows) * (Metrics.rowHeight + Metrics.gapRow) * s
    readonly property real gridH: 380 * s
    readonly property real tabsH: actionBrowse ? tabs.implicitHeight + 6 * s : 0
    readonly property real restH: rest.implicitHeight + (hasMedia ? nowPlaying.implicitHeight + Metrics.padRow * s : 0)
    readonly property real bodyH: gridMode ? gridH
        : (resting ? restH
        : (results.length > 0 ? listH
        : (searching ? loading.height : empty.height)))
    readonly property real contentH: tabsH + bodyH

    implicitWidth: cardW
    implicitHeight: search.height + divider.height + contentH + Metrics.padOuter * 2 * s

    Behavior on implicitHeight {
        NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
    }

    Providers { id: providers }

    Binding {
        target: providers.actions
        property: "activeCategory"
        value: tabs.activeCategory
        when: root.actionMode
    }

    onShownChanged: {
        if (shown) {
            root.query = "";
            root.allApps = false;
            search.clear();
            list.selectedIndex = 0;
            panel.open = false;
            Qt.callLater(search.focusField);
        }
    }
    onQueryChanged: { panel.open = false; if (query.length > 0) root.allApps = false; }

    Squircle {
        anchors.fill: parent
        radius: Metrics.radiusWindow
        power: 4
        color: Theme.cardTop
        borderColor: Theme.border
        borderWidth: 1
    }

    SearchRow {
        id: search
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: (Metrics.padOuter - 8) * root.s
        s: root.s
        resultCount: root.results.length
        totalCount: root.totalCount
        modeLabel: root.modeLabel
        onTextChanged: { root.query = text; list.selectedIndex = 0; }
        onMoved: (d) => { if (panel.open) panel.move(d); else if (root.gridMode) appGrid.move(d * root.gridColumnsForMove); else list.move(d); }
        onAccepted: { if (panel.open) panel.run(); else if (root.gridMode) appGrid.activate(); else list.activate(); }
        onDismissed: { if (panel.open) panel.open = false; else if (root.allApps) root.allApps = false; else root.requestClose(); }
        onKeyPressed: (e) => {
            if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) {
                if (root.selectedActions.length > 0)
                    panel.open = !panel.open;
                e.accepted = true;
            } else if (e.key === Qt.Key_A && (e.modifiers & Qt.ControlModifier) && root.resting) {
                root.allApps = !root.allApps;
                e.accepted = true;
            } else if (root.actionMode && e.key === Qt.Key_Tab) {
                tabs.cycle(1); e.accepted = true;
            } else if (root.actionMode && e.key === Qt.Key_Backtab) {
                tabs.cycle(-1); e.accepted = true;
            }
        }
    }

    readonly property int gridColumnsForMove: Metrics.gridColumns

    Rectangle {
        id: divider
        anchors.top: search.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        height: 1
        color: Theme.hair
    }

    CategoryTabs {
        id: tabs
        visible: root.actionBrowse
        anchors.top: divider.bottom
        anchors.topMargin: 8 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        s: root.s
    }

    RestDashboard {
        id: rest
        visible: root.resting && !root.allApps
        anchors.top: divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        s: root.s
    }

    NowPlaying {
        id: nowPlaying
        visible: root.resting && !root.allApps && root.hasMedia
        anchors.top: rest.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        s: root.s
        player: root.activePlayer
    }

    ResultGrid {
        id: appGrid
        visible: root.gridMode
        anchors.top: divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        height: root.gridH - Metrics.padRow * root.s
        s: root.s
        entries: root.gridMode ? providers.apps.allRows() : []
        onActivated: root.requestClose()
    }

    ResultList {
        id: list
        visible: !root.resting && root.results.length > 0
        anchors.top: root.actionBrowse ? tabs.bottom : divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: (Metrics.padOuter - Metrics.padRow) * root.s
        anchors.rightMargin: (Metrics.padOuter - Metrics.padRow) * root.s
        height: root.listH
        s: root.s
        results: root.results
        query: root.routed.query
        onActivated: root.requestClose()
    }

    Row {
        id: loading
        visible: root.searching
        anchors.top: root.actionBrowse ? tabs.bottom : divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        height: 40 * root.s
        spacing: 8 * root.s
        Spinner {
            anchors.verticalCenter: parent.verticalCenter
            size: 15 * root.s
            color: Theme.verm
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Searching\u2026"
            color: Theme.faint
            font.family: Theme.font
            font.pixelSize: 12 * root.s
        }
    }

    Text {
        id: empty
        visible: !root.resting && !root.searching && root.results.length === 0
        anchors.top: root.actionBrowse ? tabs.bottom : divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No matches"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 12 * root.s
        height: 40 * root.s
    }

    ActionPanel {
        id: panel
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Metrics.padOuter * root.s
        height: open ? Math.min(root.selectedActions.length, 5) * 31 * root.s + 28 * root.s : 0
        s: root.s
        actions: root.selectedActions
        onChosen: { panel.open = false; root.requestClose(); }
    }
}
