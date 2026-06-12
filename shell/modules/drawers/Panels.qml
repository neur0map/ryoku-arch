import QtQuick
import Quickshell
import Ryoku.Config
import qs.components
import qs.modules.bar as Bar
import qs.modules.clipboard as Clipboard
import qs.modules.controlcenter as ControlCenter
import qs.modules.dashboard as Dashboard
import qs.modules.island as Island
import qs.modules.launcher as Launcher
import qs.modules.notifications as Notifications
import qs.modules.obsidian as Obsidian
import qs.modules.osd as Osd
import qs.modules.session as Session
import qs.modules.sidebar as Sidebar
import qs.modules.utilities as Utilities
import qs.modules.bar.popouts as BarPopouts
import qs.modules.utilities.toasts as Toasts

Item {
    id: root

    required property ShellScreen screen
    required property DrawerVisibilities visibilities
    required property Bar.BarWrapper bar
    required property real borderThickness

    readonly property alias osd: osd
    readonly property alias osdWrapper: osdWrapper
    readonly property alias notifications: notifications
    readonly property alias session: session
    readonly property alias sessionWrapper: sessionWrapper
    readonly property alias launcher: launcher
    readonly property alias clipboard: clipboard
    readonly property alias island: island
    readonly property alias dashboard: dashboard
    readonly property alias settings: settings
    readonly property alias framePlugins: framePlugins
    readonly property alias obsidian: obsidian
    readonly property alias popouts: popoutsWrapper.content
    readonly property alias popoutsWrapper: popoutsWrapper
    readonly property alias utilities: utilities
    readonly property alias toasts: toasts
    readonly property alias sidebar: sidebar

    anchors.fill: parent
    anchors.topMargin: bar.edge === "top" ? bar.thickness : borderThickness
    anchors.bottomMargin: bar.edge === "bottom" ? bar.thickness : borderThickness
    anchors.leftMargin: bar.edge === "left" ? bar.thickness : borderThickness
    anchors.rightMargin: bar.edge === "right" ? bar.thickness : borderThickness

    Item {
        id: osdWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sessionWrapper.anchors.rightMargin + session.width * (1 - session.offsetScale)
        clip: sidebar.visible || session.visible

        implicitWidth: osd.implicitWidth * (1 - osd.offsetScale)
        implicitHeight: osd.implicitHeight

        Osd.Wrapper {
            id: osd

            screen: root.screen
            visibilities: root.visibilities
            sidebarOrSessionVisible: sidebar.visible || session.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Notifications.Wrapper {
        id: notifications

        visibilities: root.visibilities
        sidebarPanel: sidebar
        osdPanel: osdWrapper
        sessionPanel: sessionWrapper

        anchors.top: parent.top
        anchors.right: parent.right
    }

    Item {
        id: sessionWrapper

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: sidebar.width * (1 - sidebar.offsetScale)
        clip: sidebar.visible

        implicitWidth: session.implicitWidth * (1 - session.offsetScale)
        implicitHeight: session.implicitHeight

        Session.Wrapper {
            id: session

            visibilities: root.visibilities
            sidebarVisible: sidebar.visible

            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right
        }
    }

    Launcher.Wrapper {
        id: launcher

        screen: root.screen
        visibilities: root.visibilities
        panels: root

        anchors.horizontalCenter: parent.horizontalCenter
    }

    Clipboard.Wrapper {
        id: clipboard

        screen: root.screen
        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
    }

    Island.Wrapper {
        id: island

        visibilities: root.visibilities
        popouts: root.popouts
        collapsedWidth: root.bar.islandWidth

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    Dashboard.Wrapper {
        id: dashboard

        visibilities: root.visibilities
        collapsedWidth: root.bar.islandWidth

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    ControlCenter.Wrapper {
        id: settings

        screen: root.screen
        visibilities: root.visibilities

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
    }

    FramePlugins {
        id: framePlugins

        screen: root.screen
        anchors.fill: parent
    }

    Obsidian.Wrapper {
        id: obsidian

        screen: root.screen
        visibilities: root.visibilities

        anchors.bottom: parent.bottom
        anchors.left: parent.left
    }

    BarPopouts.ClipWrapper {
        id: popoutsWrapper

        screen: root.screen
        borderThickness: root.borderThickness
    }

    Utilities.Wrapper {
        id: utilities

        visibilities: root.visibilities
        sidebar: sidebar
        popouts: popoutsWrapper.content

        anchors.bottom: parent.bottom
        anchors.right: parent.right
    }

    Toasts.Toasts {
        id: toasts

        anchors.bottom: sidebar.visible ? parent.bottom : utilities.top
        anchors.right: sidebar.left
        anchors.margins: Tokens.padding.normal
    }

    Sidebar.Wrapper {
        id: sidebar

        visibilities: root.visibilities

        anchors.top: notifications.bottom
        anchors.bottom: utilities.top
        anchors.right: parent.right
    }
}
