pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Drift layout: Ryoku's own two-line browse. The top row drifts right, the
// bottom drifts left, both idle-drifting and easing to a stop under the pointer;
// a wheel pushes them faster and they ease back. Passive motion, kept alongside
// the focused layouts. Hover a tile to pick it, click or Enter to set it. Cells
// split even/odd across the two belts and reuse WallCell/ThemeCell.
Item {
    id: drift

    required property real s
    required property var model
    required property string kind
    required property color bg
    property int selIndex: 0
    property bool active: true
    property string activeKey: ""
    property bool interactive: true
    property int columns: 1
    signal focusIndex(int i)
    signal chosen(int i)

    readonly property var topCells: model ? model.filter((e, i) => i % 2 === 0) : []
    readonly property var bottomCells: model ? model.filter((e, i) => i % 2 === 1) : []
    function idxOf(entry) {
        if (!drift.model || !entry) return -1;
        for (var i = 0; i < drift.model.length; i++) {
            var m = drift.model[i];
            if (drift.kind === "theme" ? (m.id === entry.id) : (m.path === entry.path)) return i;
        }
        return -1;
    }
    readonly property string highlightKey: {
        if (!model || selIndex < 0 || selIndex >= model.length) return "";
        var e = model[selIndex];
        return drift.kind === "theme" ? (e.id || "") : (e.path || "");
    }

    readonly property int rowGap: Math.round(12 * s)
    readonly property real cH: kind === "theme"
        ? Math.round(height * 0.3)
        : Math.round(height * 0.33)
    readonly property real rowH: cH
    readonly property real cW: kind === "theme" ? Math.round(cH * 0.82) : Math.round(cH * 1.55)
    readonly property int cGap: Math.round(14 * s)
    property bool scrolling: false

    Belt {
        id: topRow
        anchors { left: parent.left; right: parent.right; bottom: parent.verticalCenter; bottomMargin: drift.rowGap / 2 }
        height: drift.rowH
        s: drift.s
        dir: 1
        topRow: true
        kind: drift.kind
        cells: drift.topCells
        cellW: drift.cW
        cellH: drift.cH
        gap: drift.cGap
        bg: drift.bg
        running: drift.active
        hovering: driftHover.hovered
        scrollHold: drift.scrolling
        highlightKey: drift.highlightKey
        activeKey: drift.activeKey
        frozen: !drift.interactive
        onEntered: (e) => drift.focusIndex(drift.idxOf(e))
        onChosen: (e) => drift.chosen(drift.idxOf(e))
    }
    Belt {
        id: bottomRow
        anchors { left: parent.left; right: parent.right; top: parent.verticalCenter; topMargin: drift.rowGap / 2 }
        height: drift.rowH
        s: drift.s
        dir: -1
        topRow: false
        kind: drift.kind
        cells: drift.bottomCells
        cellW: drift.cW
        cellH: drift.cH
        gap: drift.cGap
        bg: drift.bg
        running: drift.active
        hovering: driftHover.hovered
        scrollHold: drift.scrolling
        highlightKey: drift.highlightKey
        activeKey: drift.activeKey
        frozen: !drift.interactive
        onEntered: (e) => drift.focusIndex(drift.idxOf(e))
        onChosen: (e) => drift.chosen(drift.idxOf(e))
    }

    // a wheel pushes both belts faster; they ease back to the idle drift.
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: (e) => {
            var f = e.angleDelta.y * 3.2;
            topRow.boostBy(f);
            bottomRow.boostBy(-f);
            drift.scrolling = true;
            scrollCool.restart();
        }
    }
    Timer { id: scrollCool; interval: 450; onTriggered: drift.scrolling = false }
    HoverHandler { id: driftHover }
}
