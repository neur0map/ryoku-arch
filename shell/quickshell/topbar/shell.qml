//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    id: root

    function refresh() {
        Hyprland.refreshMonitors();
        Hyprland.refreshWorkspaces();
        Hyprland.refreshToplevels();
    }

    Component.onCompleted: refresh()

    Instantiator {
        model: DesktopEntries.applications
        delegate: QtObject {}
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) { root.refresh(); }
    }

    Timer {
        interval: 250
        repeat: true
        running: true
        property int n: 0
        onTriggered: {
            root.refresh();
            n++;
            if (Hyprland.monitors.values.length > 0 || n >= 16) running = false;
        }
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            readonly property real s: modelData ? modelData.height / 1080 : 1
            readonly property real barHeight: 34 * s
            readonly property real topGap: 8 * s

            screen: modelData
            color: "transparent"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: barHeight + topGap
            aboveWindows: true

            anchors { top: true; left: true; right: true }
            margins { top: topGap; left: 12 * s; right: 12 * s }

            implicitHeight: barHeight

            Bar {
                anchors.fill: parent
                screen: win.modelData
                screenName: win.modelData.name
                s: win.s
                barWindow: win
            }
        }
    }
}
