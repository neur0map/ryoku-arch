pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import "Singletons"

// Running-app dock for the expanded island: one icon per window on the focused
// workspace of this pill's monitor, click to focus (hl.dsp.focus). Icons sit
// dimmed and brighten on hover. Icon resolution mirrors MinimizedTray.
Row {
    id: root

    property real s: 1
    property string screenName: ""
    property bool live: true
    spacing: 9 * s

    function normAddr(a) { return (a && a.indexOf("0x") === 0) ? a : ("0x" + a); }

    readonly property int activeWs: {
        var ms = Hyprland.monitors.values;
        for (var i = 0; i < ms.length; i++)
            if (ms[i].name === root.screenName && ms[i].activeWorkspace)
                return ms[i].activeWorkspace.id;
        return Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
    }

    readonly property var items: {
        var out = [];
        var tl = Hyprland.toplevels.values;
        for (var i = 0; i < tl.length; i++) {
            var t = tl[i];
            if (t && t.workspace && t.workspace.id === root.activeWs
                && t.workspace.name.indexOf("special:") !== 0)
                out.push(t);
        }
        return out;
    }
    readonly property int count: items.length

    Repeater {
        model: root.items

        delegate: Item {
            id: chip
            required property var modelData
            width: 19 * root.s
            height: 19 * root.s
            anchors.verticalCenter: parent.verticalCenter

            Image {
                anchors.fill: parent
                sourceSize.width: Math.round(38 * root.s)
                sourceSize.height: Math.round(38 * root.s)
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                smooth: true
                source: Apps.iconFor(chip.modelData)
                opacity: area.containsMouse ? 1 : 0.62
                Behavior on opacity { NumberAnimation { duration: 120 } }
            }

            MouseArea {
                id: area
                anchors.fill: parent
                anchors.margins: -3 * root.s
                hoverEnabled: true
                enabled: root.live
                cursorShape: Qt.PointingHandCursor
                onClicked: Hyprland.dispatch('hl.dsp.focus({ window = "address:' + root.normAddr(chip.modelData.address) + '" })')
            }
        }
    }
}
