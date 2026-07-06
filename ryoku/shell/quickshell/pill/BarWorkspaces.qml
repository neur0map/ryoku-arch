pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import "Singletons"

// workspace strip: mono numerals in fixed cells with a vermilion block riding
// behind the active one. the block's leading edge chases the target fast while
// the trailing edge settles slower (the caelestia trail), so a switch reads as
// the block stretching across and contracting, not teleporting. numerals under
// the block flip to paper for contrast. click jumps, wheel walks neighbours.
Item {
    id: strip

    property real s: 1
    property int activeWsId: 1

    readonly property real cellW: 20 * s
    readonly property real cellH: 17 * s

    // ids 1..10, desktop-relative block like the Super+N binds.
    readonly property int base: Math.floor((activeWsId - 1) / 10) * 10
    readonly property var occupiedSet: {
        var occ = {};
        var v = Hyprland.workspaces.values;
        for (var i = 0; i < v.length; i++)
            if (v[i])
                occ[v[i].id] = true;
        return occ;
    }

    // trailing cells beyond 5 only appear once used, so an idle strip stays short.
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

    implicitWidth: shown * cellW
    implicitHeight: cellH

    readonly property int activeIdx: Math.max(0, Math.min(shown - 1, activeWsId - base - 1))

    function jump(id) {
        Hyprland.dispatch('hl.dsp.workspace.move({ workspace = ' + id + ', monitor = "current" })');
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + id + ' })');
    }

    function walk(dir) {
        var next = Math.max(1, Math.min(strip.shown, strip.activeIdx + 1 + dir));
        strip.jump(strip.base + next);
    }

    // active block: leading edge fast, trailing edge slow. both edges land on
    // the active cell, so at rest it is exactly one cell wide.
    Item {
        readonly property real target: strip.activeIdx * strip.cellW
        property real lead: target
        property real trailEdge: target
        onTargetChanged: {
            lead = target;
            trailEdge = target;
        }
        Behavior on lead { NumberAnimation { duration: Motion.fast; easing.type: Easing.OutCubic } }
        Behavior on trailEdge { NumberAnimation { duration: Motion.trail; easing.type: Easing.OutCubic } }

        x: Math.min(lead, trailEdge)
        width: Math.abs(lead - trailEdge) + strip.cellW
        height: strip.cellH

        Rectangle {
            anchors.fill: parent
            color: Theme.verm
        }
    }

    Row {
        Repeater {
            model: strip.shown
            delegate: Item {
                id: cell
                required property int index
                readonly property int wsId: strip.base + index + 1
                readonly property bool active: index === strip.activeIdx
                readonly property bool occupied: strip.occupiedSet[wsId] === true
                width: strip.cellW
                height: strip.cellH

                Text {
                    anchors.centerIn: parent
                    text: cell.wsId - strip.base
                    color: cell.active ? Theme.cardBot
                        : (cell.occupied ? Qt.alpha(Theme.cream, 0.78) : Qt.alpha(Theme.cream, 0.26))
                    font.family: Theme.mono
                    font.pixelSize: 9 * strip.s
                    font.weight: cell.active ? Font.Bold : Font.DemiBold
                    font.features: ({ "tnum": 1 })
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.jump(cell.wsId)
                }
            }
        }
    }

    WheelHandler {
        onWheel: (w) => strip.walk(w.angleDelta.y > 0 ? -1 : 1)
    }
}
