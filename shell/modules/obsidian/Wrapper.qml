pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.components
import qs.services

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    property matrix4x4 deformMatrix

    readonly property bool shouldBeActive: visibilities.obsidian
    readonly property int panelWidth: Math.min(Math.max(420, Math.round(screen.width * 0.2)), Math.max(380, screen.width - 160))
    readonly property int maxPanelHeight: Math.max(360, screen.height - Tokens.padding.large * 2)
    readonly property int expandedHeight: Math.min(720, maxPanelHeight)
    readonly property int panelHeight: expandedHeight
    property real offsetScale: shouldBeActive ? 0 : 1

    visible: offsetScale < 1
    anchors.bottomMargin: (-implicitHeight - 5) * offsetScale
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    opacity: 1 - offsetScale

    Behavior on offsetScale {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Behavior on implicitHeight {
        Anim {
            type: Anim.DefaultSpatial
        }
    }

    Connections {
        target: root.visibilities

        function onObsidianChanged(): void {
            if (root.visibilities.obsidian) {
                ObsidianNotes.selectedDate = new Date();
                ObsidianNotes.notesExpanded = true;
                ObsidianNotes.loadDraftForSelectedDate();
            }
        }
    }

    Loader {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Tokens.padding.large

        asynchronous: true
        active: root.shouldBeActive || root.visible

        sourceComponent: Content {
            screen: root.screen
            panelWidth: root.panelWidth - content.anchors.margins * 2
            panelHeight: root.panelHeight - content.anchors.margins * 2
        }
    }
}
