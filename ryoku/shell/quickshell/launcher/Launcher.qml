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
    property bool help: false

    signal requestClose()

    readonly property var results: shown ? Dispatcher.results(query, Metrics.maxResults) : []
    readonly property int totalCount: shown ? Dispatcher.results("", 0).length : 0
    readonly property bool resting: query.length === 0
    // grid and help are mutually exclusive body modes; exclude help here too so
    // no toggle path can leave both drawing over each other.
    readonly property bool gridMode: resting && allApps && !help

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
    // "?" prefix with a non-empty query and an available DDG answer: the
    // AnswerPanel takes the body above the Search fallback row. Guarded on
    // providers.web because the alias resolves after Providers instantiates.
    readonly property bool answerMode: routed.prefix === "?"
        && routed.query.length > 0
        && providers.web && providers.web.answer && providers.web.answer.available
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
    readonly property int visibleCount: Math.min(results.length, visibleRows)
    // each distinct type group draws an 18px section header, so the list must be
    // tall enough for the rows AND their headers — otherwise the last row clips
    // (the subtitle vanishes and the action verb sits wrong).
    readonly property int sectionCount: {
        var n = 0, prev = null;
        for (var i = 0; i < visibleCount; i++) {
            var t = results[i] ? (results[i].type || "") : "";
            if (i === 0 || t !== prev) n++;
            prev = t;
        }
        return n;
    }
    readonly property real listH: visibleCount * (Metrics.rowHeight + Metrics.gapRow) * s + sectionCount * Metrics.sectionH * s
    readonly property real gridH: 380 * s
    readonly property real tabsH: actionBrowse ? tabs.implicitHeight + 6 * s : 0
    readonly property real restH: rest.implicitHeight + (hasMedia ? nowPlaying.implicitHeight + Metrics.padRow * s : 0)
    // Extra body slice for the instant-answer panel; padRow separates it from
    // the Search fallback row that stays underneath so Enter still targets it.
    readonly property real answerH: answerMode ? answerPanel.implicitHeight + Metrics.padRow * s : 0
    readonly property real bodyH: help ? helpPanel.implicitHeight
        : gridMode ? gridH
        : (resting ? restH
        : (answerH + (results.length > 0 ? listH
        : (searching ? loading.height : empty.height))))
    readonly property real contentH: tabsH + bodyH

    implicitWidth: cardW
    implicitHeight: search.height + divider.height + contentH + Metrics.padOuter * 2 * s
    // height as if at rest (no results/tabs). The window anchors the card top off
    // this so typing grows the body downward while the search row stays put.
    readonly property real restingHeight: search.height + divider.height + restH + Metrics.padOuter * 2 * s

    Behavior on implicitHeight {
        NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
    }

    // open/close morph: the card inflates from its top edge (where the search row
    // sits) and fades, rather than popping in at full size. Synced to the window
    // timer in shell.qml so the close plays fully before the window drops.
    transformOrigin: Item.Top
    opacity: shown ? 1 : 0
    scale: shown ? 1 : 0.92
    Behavior on opacity { NumberAnimation { duration: Motion.window; easing.type: Easing.OutCubic } }
    Behavior on scale {
        NumberAnimation { duration: Motion.window; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
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
            root.help = false;
            search.clear();
            list.selectedIndex = 0;
            panel.open = false;
            Qt.callLater(search.focusField);
        }
    }
    onQueryChanged: { panel.open = false; if (query.length > 0) { root.allApps = false; root.help = false; } }

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
        gridActive: root.gridMode
        helpActive: root.help
        onTextChanged: { root.query = text; list.selectedIndex = 0; }
        onMoved: (d) => { if (panel.open) panel.move(d); else if (root.gridMode) appGrid.move(d * root.gridColumnsForMove); else list.move(d); }
        onAccepted: { if (panel.open) panel.run(); else if (root.gridMode) appGrid.activate(); else list.activate(); }
        onDismissed: { if (panel.open) panel.open = false; else if (root.help) root.help = false; else if (root.allApps) root.allApps = false; else root.requestClose(); }
        onGridToggled: {
            if (root.gridMode) {
                root.allApps = false;
            } else {
                search.clear();
                root.allApps = true;
                root.help = false;
            }
        }
        onHelpToggled: {
            root.help = !root.help;
            if (root.help) { search.clear(); root.allApps = false; }
        }
        onKeyPressed: (e) => {
            if (e.key === Qt.Key_K && (e.modifiers & Qt.ControlModifier)) {
                if (root.selectedActions.length > 0)
                    panel.open = !panel.open;
                e.accepted = true;
            } else if (e.key === Qt.Key_A && (e.modifiers & Qt.ControlModifier) && root.resting) {
                root.allApps = !root.allApps;
                if (root.allApps) root.help = false;
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
        visible: root.resting && !root.allApps && !root.help
        anchors.top: divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        s: root.s
    }

    HelpPanel {
        id: helpPanel
        visible: root.help
        anchors.top: divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        s: root.s
    }

    AnswerPanel {
        id: answerPanel
        visible: root.answerMode
        anchors.top: divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        s: root.s
        answer: providers.web ? providers.web.answer : ({ available: false })
    }

    NowPlaying {
        id: nowPlaying
        visible: root.resting && !root.allApps && !root.help && root.hasMedia
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
        anchors.top: root.answerMode ? answerPanel.bottom : (root.actionBrowse ? tabs.bottom : divider.bottom)
        anchors.topMargin: root.answerMode ? Metrics.padRow * root.s : 6 * root.s
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
        anchors.top: root.answerMode ? answerPanel.bottom : (root.actionBrowse ? tabs.bottom : divider.bottom)
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
        anchors.top: root.answerMode ? answerPanel.bottom : (root.actionBrowse ? tabs.bottom : divider.bottom)
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
