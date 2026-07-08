pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "Singletons"

// the workspace indicator, per bar skin.
//   caelestia = one container pill; equal numeral cells inside it with a
//               fully rounded accent indicator sliding behind the active one
//               (emphasized curve, stretchy leading/trailing edges); the
//               numeral over the indicator flips dark.
//   noctalia  = free-standing mini pills, one per workspace: dots for empty,
//               brighter dots for occupied, and the active one grown into a
//               wide accent lozenge carrying its number (width animates).
//   aegis     = numeral cells, the active one marked by an accent underline.
//   stele     = numeral cells, the active one boxed in an engraved frame.
// click jumps, wheel walks neighbours. cells past five appear once used.
Item {
    id: strip

    property real s: 1
    property int activeWsId: 1
    property bool vertical: false
    readonly property string style: Config.barStyle
    readonly property bool caelestia: style === "caelestia"
    readonly property bool aegis: style === "aegis"
    readonly property bool stele: style === "stele"
    readonly property bool cells: caelestia || aegis || stele

    // caelestia cell metrics (inside the container pill).
    readonly property real cellW: vertical ? 21 * s : 24 * s
    readonly property real cellH: vertical ? 24 * s : 21 * s
    readonly property real cellSpan: vertical ? cellH : cellW
    // noctalia pill metrics.
    readonly property real dotSize: 10 * s
    readonly property real activeLen: dotSize * 2.2
    readonly property real dotGap: 4 * s

    readonly property int base: Math.floor((activeWsId - 1) / 10) * 10
    // occupancy = which workspaces own a window, from hyprctl. Quickshell's
    // bulk refresh doesn't parse this Hyprland's IPC, so its own workspace and
    // toplevel models only track what changed since the shell started and miss
    // windows opened before a reload. re-query at startup and on any
    // window/workspace event so occupied-only is always right.
    property var occupiedSet: ({})
    Process {
        id: clientsProc
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var occ = {};
                    var cs = JSON.parse(this.text);
                    for (var i = 0; i < cs.length; i++)
                        if (cs[i].workspace && cs[i].workspace.id > 0)
                            occ[cs[i].workspace.id] = true;
                    strip.occupiedSet = occ;
                } catch (e) {}
            }
        }
    }
    Timer { id: occDebounce; interval: 80; onTriggered: clientsProc.running = true }
    Component.onCompleted: clientsProc.running = true
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            var n = event.name;
            if (n === "openwindow" || n === "closewindow" || n.indexOf("movewindow") === 0
                || n.indexOf("createworkspace") === 0 || n.indexOf("destroyworkspace") === 0)
                occDebounce.restart();
        }
    }
    // which workspaces to show. occupied-only (the default) lists the ones
    // with windows plus the active one, so empty numbers vanish; otherwise a
    // contiguous 1..N run (N grows past 5 as higher spaces get used) with
    // empties dimmed.
    readonly property var wsList: {
        var out = [];
        if (Config.barOccupiedWorkspaces) {
            for (var i = 1; i <= 10; i++) {
                var id = base + i;
                if (occupiedSet[id] || id === activeWsId)
                    out.push(id);
            }
            if (out.length === 0)
                out.push(activeWsId);
        } else {
            var n = 5;
            for (var j = 10; j > 5; j--) {
                if (occupiedSet[base + j] || activeWsId === base + j) { n = j; break; }
            }
            for (var k = 1; k <= n; k++)
                out.push(base + k);
        }
        return out;
    }
    readonly property int count: wsList.length
    readonly property int activeIdx: Math.max(0, wsList.indexOf(activeWsId))

    implicitWidth: cells ? (vertical ? cellW : count * cellW)
        : (vertical ? dotSize : count * dotSize + (count - 1) * dotGap + (activeLen - dotSize))
    implicitHeight: cells ? (vertical ? count * cellH : cellH)
        : (vertical ? count * dotSize + (count - 1) * dotGap + (activeLen - dotSize) : dotSize)

    function jump(id) {
        Hyprland.dispatch('hl.dsp.workspace.move({ workspace = ' + id + ', monitor = "current" })');
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + id + ' })');
    }
    function walk(dir) {
        var i = strip.activeIdx + dir;
        if (i >= 0 && i < strip.wsList.length)
            strip.jump(strip.wsList[i]);
    }
    WheelHandler {
        onWheel: (w) => strip.walk(w.angleDelta.y > 0 ? -1 : 1)
    }

    // ---- numeral cells: caelestia, aegis, stele --------------------------
    Item {
        visible: strip.cells
        anchors.fill: parent

        // sliding accent indicator: fully rounded, inset a hair inside the
        // container, leading edge chasing fast and trailing edge settling on
        // the emphasized curve so a switch stretches across and contracts.
        Item {
            readonly property real inset: 2.5 * strip.s
            readonly property real target: strip.activeIdx * strip.cellSpan
            property real lead: target
            property real trailEdge: target
            onTargetChanged: {
                lead = target;
                trailEdge = target;
            }
            Behavior on lead {
                NumberAnimation { duration: 250; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedCurve }
            }
            Behavior on trailEdge {
                NumberAnimation { duration: 450; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.emphasizedCurve }
            }

            x: strip.vertical ? inset : Math.min(lead, trailEdge) + inset
            y: strip.vertical ? Math.min(lead, trailEdge) + inset : inset
            width: (strip.vertical ? strip.cellW : Math.abs(lead - trailEdge) + strip.cellW) - 2 * inset
            height: (strip.vertical ? Math.abs(lead - trailEdge) + strip.cellH : strip.cellH) - 2 * inset

            Rectangle {
                visible: strip.caelestia
                anchors.fill: parent
                radius: Math.min(width, height) / 2
                color: Theme.verm
            }
            Rectangle {
                visible: strip.stele
                anchors.fill: parent
                color: "transparent"
                border.width: Math.max(1, strip.s)
                border.color: Theme.verm
            }
            Rectangle {
                visible: strip.aegis
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: Math.max(2, 2 * strip.s)
                color: Theme.verm
            }
        }

        Grid {
            columns: strip.vertical ? 1 : strip.count
            Repeater {
                model: strip.wsList
                delegate: Item {
                    id: cCell
                    required property int modelData
                    readonly property int wsId: cCell.modelData
                    readonly property bool active: cCell.wsId === strip.activeWsId
                    readonly property bool occupied: strip.occupiedSet[wsId] === true
                    width: strip.cellW
                    height: strip.cellH

                    Text {
                        anchors.centerIn: parent
                        text: cCell.wsId - strip.base
                        color: cCell.active ? (strip.caelestia ? Theme.cardBot : Theme.verm)
                            : (cCell.occupied ? Theme.cream : Qt.alpha(Theme.subtle, 0.45))
                        font.family: strip.caelestia ? Theme.font : Theme.mono
                        font.pixelSize: 10.5 * strip.s
                        font.weight: cCell.active ? Font.Bold : Font.Medium
                        font.features: ({ "tnum": 1 })
                        Behavior on color { ColorAnimation { duration: Motion.effects } }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: strip.jump(cCell.wsId)
                    }
                }
            }
        }
    }

    // ---- noctalia dialect ---------------------------------------------------
    Grid {
        visible: !strip.cells
        anchors.centerIn: parent
        columns: strip.vertical ? 1 : strip.count
        columnSpacing: strip.dotGap
        rowSpacing: strip.dotGap
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: strip.wsList
            delegate: Rectangle {
                id: nPill
                required property int modelData
                readonly property int wsId: nPill.modelData
                readonly property bool active: nPill.wsId === strip.activeWsId
                readonly property bool occupied: strip.occupiedSet[wsId] === true
                width: strip.vertical ? strip.dotSize : (active ? strip.activeLen : strip.dotSize)
                height: strip.vertical ? (active ? strip.activeLen : strip.dotSize) : strip.dotSize
                radius: strip.dotSize / 2
                color: active ? Theme.verm
                    : (occupied ? Qt.alpha(Theme.cream, 0.55) : Qt.alpha(Theme.cream, 0.18))
                Behavior on width { NumberAnimation { duration: Motion.effects; easing.type: Easing.OutCubic } }
                Behavior on height { NumberAnimation { duration: Motion.effects; easing.type: Easing.OutCubic } }
                Behavior on color { ColorAnimation { duration: Motion.effects } }

                Text {
                    anchors.centerIn: parent
                    visible: nPill.active
                    text: nPill.wsId - strip.base
                    color: Theme.cardBot
                    font.family: Theme.font
                    font.pixelSize: 8.5 * strip.s
                    font.weight: Font.Bold
                    font.features: ({ "tnum": 1 })
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.jump(nPill.wsId)
                }
            }
        }
    }
}
