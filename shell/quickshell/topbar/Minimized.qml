pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "Singletons"

Item {
    id: min

    property real s: 1

    readonly property var entries: {
        var out = [];
        var t = Hyprland.toplevels.values;
        for (var i = 0; i < t.length; i++) {
            var w = t[i].workspace;
            if (w && w.name === "special:minimized")
                out.push(t[i]);
        }
        return out;
    }

    function iconFor(toplevel) {
        var cls = toplevel.lastIpcObject ? toplevel.lastIpcObject.class : "";
        if (!cls)
            return "";
        var e = DesktopEntries.heuristicLookup(cls);
        return e && e.icon ? Quickshell.iconPath(e.icon, true) : "";
    }

    function restore(toplevel) {
        var ws = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1;
        if (ws < 0)
            return;
        Hyprland.dispatch('hl.dsp.window.move({ workspace = ' + ws + ', window = "address:0x' + toplevel.address + '", follow = true })');
    }

    visible: entries.length > 0
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: 28 * min.s

    RowLayout {
        id: row
        anchors.fill: parent
        spacing: 2 * min.s

        Repeater {
            model: min.entries

            delegate: Item {
                id: slot

                required property var modelData

                Layout.preferredWidth: 28 * min.s
                Layout.preferredHeight: 28 * min.s

                Rectangle {
                    anchors.fill: parent
                    radius: 7 * min.s
                    color: area.containsMouse ? Theme.sheen : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottomMargin: 2 * min.s
                    width: 5 * min.s
                    height: 2 * min.s
                    radius: 1
                    color: Theme.verm
                    opacity: 0.7
                }

                Image {
                    anchors.centerIn: parent
                    source: min.iconFor(slot.modelData)
                    sourceSize.width: 36
                    sourceSize.height: 36
                    width: 18 * min.s
                    height: 18 * min.s
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                MouseArea {
                    id: area
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: min.restore(slot.modelData)
                }
            }
        }
    }
}
