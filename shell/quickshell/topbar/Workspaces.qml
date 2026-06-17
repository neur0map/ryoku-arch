pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import "Singletons"

Item {
    id: workspaces

    property string screenName: ""
    property real s: 1

    readonly property var range: {
        if (screenName === "DP-1") return [1, 2, 3, 4, 5];
        if (screenName === "HDMI-A-1") return [6, 7, 8, 9, 10];
        return [];
    }

    readonly property string activeName: {
        var mons = Hyprland.monitors.values;
        for (var i = 0; i < mons.length; i++)
            if (mons[i].name === screenName)
                return mons[i].activeWorkspace ? mons[i].activeWorkspace.name : "";
        return "";
    }

    function iconFromName(str) {
        if (!str)
            return "";
        var e = DesktopEntries.heuristicLookup(str);
        if (e && e.icon) {
            var p = Quickshell.iconPath(e.icon, true);
            if (p)
                return p;
        }
        return Quickshell.iconPath(str.toLowerCase(), true);
    }

    function firstWord(s) {
        if (!s)
            return "";
        var parts = s.split(/[\s\u2014|:()-]+/);
        return parts.length ? parts[0] : "";
    }

    function iconForWindow(o) {
        if (!o)
            return "";
        return iconFromName(o.class)
            || iconFromName(o.initialClass)
            || iconFromName(firstWord(o.title))
            || iconFromName(firstWord(o.initialTitle));
    }

    function iconFor(name) {
        var t = Hyprland.toplevels.values;
        for (var i = 0; i < t.length; i++) {
            var w = t[i].workspace;
            if (!w || w.name !== name)
                continue;
            var ic = iconForWindow(t[i].lastIpcObject);
            if (ic)
                return ic;
        }
        return "";
    }

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5 * workspaces.s

        Repeater {
            model: workspaces.range

            delegate: Item {
                id: slot

                required property var modelData

                readonly property string wsName: String(modelData)
                readonly property bool isActive: workspaces.activeName === wsName
                readonly property string iconSource: workspaces.iconFor(wsName)

                Layout.preferredWidth: 23 * workspaces.s
                Layout.preferredHeight: 23 * workspaces.s

                Rectangle {
                    id: bg
                    anchors.fill: parent
                    radius: 6
                    color: Theme.slotBg
                    border.width: 1
                    border.color: Theme.slotBorder

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: slot.isActive
                        opacity: 0.55
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: Theme.vermLit }
                            GradientStop { position: 1.0; color: Theme.vermDeep }
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        visible: slot.isActive
                        color: "transparent"
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.18)
                    }
                }

                Image {
                    anchors.centerIn: parent
                    visible: slot.iconSource !== ""
                    source: slot.iconSource
                    sourceSize.width: 96
                    sourceSize.height: 96
                    width: 15 * workspaces.s
                    height: 15 * workspaces.s
                    fillMode: Image.PreserveAspectFit
                    smooth: true
                    mipmap: true
                    asynchronous: true
                }

                Text {
                    anchors.centerIn: parent
                    visible: slot.iconSource === ""
                    text: slot.wsName
                    color: Theme.cream
                    opacity: slot.isActive ? 1.0 : 0.4
                    font.family: Theme.font
                    font.pixelSize: 11 * workspaces.s
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch('hl.dsp.focus({workspace="' + slot.wsName + '"})')
                }
            }
        }
    }
}
