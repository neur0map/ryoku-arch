pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import "Singletons"

// the workspace indicator, in the two reference dialects.
//   caelestia = one container pill; equal numeral cells inside it with a
//               fully rounded accent indicator sliding behind the active one
//               (emphasized curve, stretchy leading/trailing edges); the
//               numeral over the indicator flips dark.
//   noctalia  = free-standing mini pills, one per workspace: dots for empty,
//               brighter dots for occupied, and the active one grown into a
//               wide accent lozenge carrying its number (width animates).
// click jumps, wheel walks neighbours. cells past five appear once used.
Item {
    id: strip

    property real s: 1
    property int activeWsId: 1
    property bool vertical: false
    readonly property bool caelestia: Config.barStyle === "caelestia"

    // caelestia cell metrics (inside the container pill).
    readonly property real cellW: vertical ? 21 * s : 24 * s
    readonly property real cellH: vertical ? 24 * s : 21 * s
    readonly property real cellSpan: vertical ? cellH : cellW
    // noctalia pill metrics.
    readonly property real dotSize: 10 * s
    readonly property real activeLen: dotSize * 2.2
    readonly property real dotGap: 4 * s

    readonly property int base: Math.floor((activeWsId - 1) / 10) * 10
    readonly property var occupiedSet: {
        var occ = {};
        var v = Hyprland.workspaces.values;
        for (var i = 0; i < v.length; i++)
            if (v[i])
                occ[v[i].id] = true;
        return occ;
    }
    readonly property int shown: {
        var n = 5;
        for (var i = 10; i > 5; i--) {
            if (occupiedSet[base + i] || activeWsId === base + i) {
                n = i;
                break;
            }
        }
        return n;
    }
    readonly property int activeIdx: Math.max(0, Math.min(shown - 1, activeWsId - base - 1))

    implicitWidth: caelestia ? (vertical ? cellW : shown * cellW)
        : (vertical ? dotSize : shown * dotSize + (shown - 1) * dotGap + (activeLen - dotSize))
    implicitHeight: caelestia ? (vertical ? shown * cellH : cellH)
        : (vertical ? shown * dotSize + (shown - 1) * dotGap + (activeLen - dotSize) : dotSize)

    function jump(id) {
        Hyprland.dispatch('hl.dsp.workspace.move({ workspace = ' + id + ', monitor = "current" })');
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + id + ' })');
    }
    function walk(dir) {
        var next = Math.max(1, Math.min(strip.shown, strip.activeIdx + 1 + dir));
        strip.jump(strip.base + next);
    }
    WheelHandler {
        onWheel: (w) => strip.walk(w.angleDelta.y > 0 ? -1 : 1)
    }

    // ---- caelestia dialect ------------------------------------------------
    Item {
        visible: strip.caelestia
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
                anchors.fill: parent
                radius: Math.min(width, height) / 2
                color: Theme.verm
            }
        }

        Grid {
            columns: strip.vertical ? 1 : strip.shown
            Repeater {
                model: strip.shown
                delegate: Item {
                    id: cCell
                    required property int index
                    readonly property int wsId: strip.base + index + 1
                    readonly property bool active: index === strip.activeIdx
                    readonly property bool occupied: strip.occupiedSet[wsId] === true
                    width: strip.cellW
                    height: strip.cellH

                    Text {
                        anchors.centerIn: parent
                        text: cCell.wsId - strip.base
                        color: cCell.active ? Theme.cardBot
                            : (cCell.occupied ? Theme.cream : Qt.alpha(Theme.subtle, 0.45))
                        font.family: Theme.font
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
        visible: !strip.caelestia
        anchors.centerIn: parent
        columns: strip.vertical ? 1 : strip.shown
        columnSpacing: strip.dotGap
        rowSpacing: strip.dotGap
        verticalItemAlignment: Grid.AlignVCenter
        horizontalItemAlignment: Grid.AlignHCenter

        Repeater {
            model: strip.shown
            delegate: Rectangle {
                id: nPill
                required property int index
                readonly property int wsId: strip.base + index + 1
                readonly property bool active: index === strip.activeIdx
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
