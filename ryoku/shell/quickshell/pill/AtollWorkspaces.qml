pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Hyprland
import Quickshell.Io
import "Singletons"

// atoll workspaces: free-standing numbered pills with a bone chip sliding behind
// the active one -- Ryoku's inversion standing in for ilyamiro's mauve indicator.
// occupied pills carry a faint plate; empties dim; hover lifts. click jumps,
// wheel walks. occupancy comes from hyprctl (Quickshell's model misses windows
// opened before a reload), re-queried on any window / workspace event.
Item {
    id: strip

    property real s: 1
    property int activeWsId: 1
    property real slotH: 26 * s
    // ryoku variant: Space Grotesk + square pills (set by AtollBar).
    property bool ryoku: false

    readonly property real pillH: strip.slotH
    readonly property real pillW: Math.round(strip.slotH + 4 * s)
    readonly property real gap: 6 * s
    readonly property real step: pillW + gap

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

    readonly property int base: Math.floor((activeWsId - 1) / 10) * 10
    readonly property var wsList: {
        var out = [];
        for (var i = 1; i <= 10; i++) {
            var id = base + i;
            if (occupiedSet[id] || id === activeWsId)
                out.push(id);
        }
        if (out.length === 0)
            out.push(activeWsId);
        return out;
    }
    readonly property int count: wsList.length
    readonly property int activeIdx: Math.max(0, wsList.indexOf(activeWsId))

    implicitWidth: count * pillW + (count - 1) * gap
    implicitHeight: pillH

    function jump(id) {
        Hyprland.dispatch('hl.dsp.workspace.move({ workspace = ' + id + ', monitor = "current" })');
        Hyprland.dispatch('hl.dsp.focus({ workspace = ' + id + ' })');
    }
    function walk(dir) {
        var i = strip.activeIdx + dir;
        if (i >= 0 && i < strip.wsList.length)
            strip.jump(strip.wsList[i]);
    }
    WheelHandler { onWheel: (w) => strip.walk(w.angleDelta.y > 0 ? -1 : 1) }

    // the bone chip, sliding behind the active pill (lower z than the numerals).
    Rectangle {
        x: strip.activeIdx * strip.step
        y: 0
        width: strip.pillW
        height: strip.pillH
        radius: strip.ryoku ? 3 * strip.s : 10 * strip.s
        color: Theme.bright
        visible: strip.count > 0
        Behavior on x { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
    }

    Row {
        spacing: strip.gap
        Repeater {
            model: strip.wsList
            delegate: Rectangle {
                id: pill
                required property int modelData
                readonly property int wsId: pill.modelData
                readonly property bool active: pill.wsId === strip.activeWsId
                readonly property bool occupied: strip.occupiedSet[pill.wsId] === true
                width: strip.pillW
                height: strip.pillH
                radius: strip.ryoku ? 3 * strip.s : 10 * strip.s
                color: pill.active ? "transparent"
                    : (pa.containsMouse ? Qt.alpha(Theme.cream, 0.10)
                    : (pill.occupied ? Qt.alpha(Theme.cream, 0.13) : "transparent"))
                scale: pa.containsMouse && !pill.active ? 1.08 : 1.0
                Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: pill.wsId - strip.base
                    color: pill.active ? Theme.cardBot
                        : (pill.occupied ? Theme.cream : Qt.alpha(Theme.subtle, 0.5))
                    font.family: strip.ryoku ? Theme.font : Theme.mono
                    font.pixelSize: Math.round(strip.slotH * 0.5)
                    font.weight: pill.active ? Font.Bold : Font.Medium
                    font.features: ({ "tnum": 1 })
                    Behavior on color { ColorAnimation { duration: 200 } }
                }
                MouseArea {
                    id: pa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: strip.jump(pill.wsId)
                }
            }
        }
    }
}
