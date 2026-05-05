pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.bar
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property var screen: root.QsWindow.window?.screen
    property var brightnessMonitor: Brightness.getMonitorForScreen(screen)

    readonly property string leftAction: Config.options?.bar?.leftScrollAction ?? "brightness"
    readonly property string rightAction: Config.options?.bar?.rightScrollAction ?? "volume"

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

    // Hidden content sizers - the frame reads their implicitWidth to set notch widths.
    RyokuLeftIsland {
        id: leftSizer
        visible: false
        parentWindow: root.QsWindow.window
    }
    RyokuCenterIsland {
        id: centerSizer
        visible: false
    }
    RyokuRightIsland {
        id: rightSizer
        visible: false
    }

    // Notch widths track content; Behavior gives a bouncy resize when the
    // active-window title (or any other content) changes width.
    property int leftNotchWidth: Math.max(140, leftSizer.implicitWidth + 16)
    property int centerNotchWidth: Math.max(120, centerSizer.implicitWidth + 16)
    property int rightNotchWidth: Math.max(140, rightSizer.implicitWidth + 16)

    Behavior on leftNotchWidth {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }
    Behavior on centerNotchWidth {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }
    Behavior on rightNotchWidth {
        enabled: Appearance.animationsEnabled
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutBack
            easing.overshoot: 1.6
        }
    }

    // Single Canvas frame: thin top strip + three drop-down notches.
    RyokuTopFrame {
        id: frame
        anchors.fill: parent
        leftWidth: root.leftNotchWidth
        centerWidth: root.centerNotchWidth
        rightWidth: root.rightNotchWidth
        notchHeight: Appearance.sizes.barHeight
    }

    // Left notch content + scroll region.
    Item {
        id: leftNotch
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.leftNotchWidth

        RyokuLeftIsland {
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

    // Center notch content + scroll region.
    Item {
        id: centerNotch
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.centerNotchWidth

        RyokuCenterIsland {
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

    // Right notch content + scroll region.
    Item {
        id: rightNotch
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: root.rightNotchWidth

        RyokuRightIsland {
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
