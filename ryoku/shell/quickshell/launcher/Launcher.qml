import QtQuick
import Quickshell
import "Singletons"
import "providers"

// The command palette body: a search row over either the rest dashboard (empty
// query) or the ranked result list. Grows and shrinks with its content on the
// Ryoku morph curve. Providers register with the dispatcher; this view only
// renders what the dispatcher returns.
Item {
    id: root

    property real s: 1
    property bool shown: false
    property string query: ""

    signal requestClose()

    readonly property var results: shown ? Dispatcher.results(query, Metrics.maxResults) : []
    readonly property int totalCount: shown ? Dispatcher.results("", 0).length : 0
    readonly property bool resting: query.length === 0

    readonly property real cardW: Metrics.windowW * s
    readonly property int visibleRows: 8
    readonly property real listH: Math.min(results.length, visibleRows) * (Metrics.rowHeight + Metrics.gapRow) * s
    readonly property real contentH: resting ? rest.implicitHeight : (results.length > 0 ? listH : empty.implicitHeight)

    implicitWidth: cardW
    implicitHeight: search.height + divider.height + contentH + Metrics.padOuter * 2 * s

    Behavior on implicitHeight {
        NumberAnimation { duration: Motion.morph; easing.type: Motion.easeMorph; easing.bezierCurve: Motion.morphCurve }
    }

    // Every provider registers itself with the dispatcher on load; the aggregator
    // instantiates them all. The view only renders what the dispatcher returns.
    Providers {}

    onShownChanged: {
        if (shown) {
            root.query = "";
            search.clear();
            list.selectedIndex = 0;
            Qt.callLater(search.focusField);
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: Metrics.radiusWindow * root.s
        color: Theme.cardTop
        border.width: 1
        border.color: Theme.border
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
        onTextChanged: { root.query = text; list.selectedIndex = 0; }
        onMoved: (d) => list.move(d)
        onAccepted: { list.activate(); }
        onDismissed: root.requestClose()
    }

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

    RestDashboard {
        id: rest
        visible: root.resting
        anchors.top: divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Metrics.padOuter * root.s
        anchors.rightMargin: Metrics.padOuter * root.s
        s: root.s
    }

    ResultList {
        id: list
        visible: !root.resting && root.results.length > 0
        anchors.top: divider.bottom
        anchors.topMargin: 6 * root.s
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: (Metrics.padOuter - Metrics.padRow) * root.s
        anchors.rightMargin: (Metrics.padOuter - Metrics.padRow) * root.s
        height: root.listH
        s: root.s
        results: root.results
        query: root.query
        onActivated: root.requestClose()
    }

    Text {
        id: empty
        visible: !root.resting && root.results.length === 0
        anchors.top: divider.bottom
        anchors.topMargin: Metrics.padRow * root.s
        anchors.horizontalCenter: parent.horizontalCenter
        text: "No matches"
        color: Theme.faint
        font.family: Theme.font
        font.pixelSize: 12 * root.s
        implicitHeight: 40 * root.s
    }
}
