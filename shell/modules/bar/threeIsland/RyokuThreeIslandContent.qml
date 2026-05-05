pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar
import QtQuick
import QtQuick.Layouts

Item {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    readonly property string leftAction: Config.options?.bar?.leftScrollAction ?? "brightness"
    readonly property string rightAction: Config.options?.bar?.rightScrollAction ?? "volume"
    readonly property real centerInset: Appearance.sizes.hyprlandGapsOut

    // Right-click context menu plumbing (mirrors BarContent.qml)
    Item { id: barContextMenuAnchor; width: 1; height: 1 }
    function openBarContextMenu(clickX, clickY, mouseArea) {
        const mapped = mouseArea.mapToItem(root, clickX, clickY)
        barContextMenuAnchor.x = mapped.x
        barContextMenuAnchor.y = (Config.options?.bar?.bottom ?? false) ? 0 : root.height
        barContextMenu.active = true
    }
    ContextMenu {
        id: barContextMenu
        anchorItem: barContextMenuAnchor
        popupAbove: Config.options?.bar?.bottom ?? false
        closeOnFocusLost: true
        closeOnHoverLost: true
        model: [
            {
                iconName: "browse_activity",
                monochromeIcon: true,
                text: Translation.tr("Mission Center"),
                action: () => Session.launchTaskManager(),
            },
            { type: "separator" },
            {
                iconName: "settings",
                monochromeIcon: true,
                text: Translation.tr("Settings"),
                action: () => Quickshell.execDetached([Quickshell.shellPath("scripts/ryoku-shell"), "settings"]),
            },
        ]
    }

    function performScrollAction(action: string, isUp: bool): void {
        if (action === "brightness") {
            const step = 0.05;
            root.brightnessMonitor.setBrightness(root.brightnessMonitor.brightness + (isUp ? step : -step));
        } else if (action === "volume") {
            if (isUp) Audio.incrementVolume();
            else Audio.decrementVolume();
        } else if (action === "workspace") {
            let up = isUp;
            if (Config.options?.bar?.workspaces?.invertScroll ?? false) up = !up;
            if (CompositorService.isNiri) {
                if (up) NiriService.focusWorkspaceUp();
                else NiriService.focusWorkspaceDown();
            } else if (CompositorService.isHyprland) {
                Hyprland.dispatch(up ? "workspace r-1" : "workspace r+1");
            }
        }
    }
    function closeOSD(action: string): void {
        if (action === "brightness") GlobalStates.osdBrightnessOpen = false;
        else if (action === "volume") GlobalStates.osdVolumeOpen = false;
    }

    // ----- Left pill (hugs TL) -----
    RyokuIsland {
        id: leftPill
        hugLeft: true
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: leftIsland.implicitWidth

        RyokuLeftIsland {
            id: leftIsland
            anchors.fill: parent
            parentWindow: root.QsWindow.window
        }

        FocusedScrollMouseArea {
            anchors.fill: parent
            onScrollDown: root.performScrollAction(root.leftAction, false)
            onScrollUp: root.performScrollAction(root.leftAction, true)
            onMovedAway: root.closeOSD(root.leftAction)
            onPressed: event => {
                if (event.button === Qt.LeftButton)
                    GlobalStates.sidebarLeftOpen = !GlobalStates.sidebarLeftOpen;
                else if (event.button === Qt.RightButton)
                    root.openBarContextMenu(event.x, event.y, this)
            }
        }
    }

    // ----- Center pill (floating, fully rounded) -----
    RyokuIsland {
        id: centerPill
        fullyRounded: true
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: root.centerInset
        height: parent.height - 2 * root.centerInset
        width: centerIsland.implicitWidth

        RyokuCenterIsland {
            id: centerIsland
            anchors.fill: parent
        }

        FocusedScrollMouseArea {
            anchors.fill: parent
            onScrollDown: root.performScrollAction("workspace", false)
            onScrollUp: root.performScrollAction("workspace", true)
            onPressed: event => {
                if (event.button === Qt.RightButton)
                    root.openBarContextMenu(event.x, event.y, this)
            }
        }
    }

    // ----- Right pill (hugs TR) -----
    RyokuIsland {
        id: rightPill
        hugRight: true
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: rightIsland.implicitWidth

        RyokuRightIsland {
            id: rightIsland
            anchors.fill: parent
        }

        FocusedScrollMouseArea {
            anchors.fill: parent
            onScrollDown: root.performScrollAction(root.rightAction, false)
            onScrollUp: root.performScrollAction(root.rightAction, true)
            onMovedAway: root.closeOSD(root.rightAction)
            onPressed: event => {
                if (event.button === Qt.LeftButton)
                    GlobalStates.sidebarRightOpen = !GlobalStates.sidebarRightOpen;
                else if (event.button === Qt.RightButton)
                    root.openBarContextMenu(event.x, event.y, this)
            }
        }
    }
}
