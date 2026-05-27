pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Ryoku.Config
import qs.modules.bar as Bar

Region {
    id: root

    required property Bar.BarWrapper bar
    required property Panels panels
    required property var win

    readonly property real borderThickness: win.contentItem.Config.border.thickness
    readonly property real clampedThickness: win.contentItem.Config.border.clampedThickness

    function panelWidth(panel: Item): real {
        return Math.max(panel.width, panel.implicitWidth ?? 0);
    }

    function panelHeight(panel: Item): real {
        return Math.max(panel.height, panel.implicitHeight ?? 0);
    }

    x: bar.clampedWidth + win.dragMaskPadding
    y: clampedThickness + win.dragMaskPadding
    width: win.width - bar.clampedWidth - clampedThickness - win.dragMaskPadding * 2
    height: win.height - clampedThickness * 2 - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: root.panelHeight(panel) * (1 - root.panels.dashboard.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.settings
        y: 0
        height: root.panelHeight(panel) * (1 - root.panels.settings.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.wallhaven
        x: root.win.width - width
        y: 0
        width: root.panelWidth(panel) * (1 - root.panels.wallhaven.offsetScale) + root.borderThickness
        height: root.panelHeight(panel) * (1 - root.panels.wallhaven.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        height: panel.height + (root.panels.launcher.openProgress > 0 ? root.borderThickness : 0)
    }

    R {
        panel: root.panels.island
        y: 0
        height: panel.height * (1 - root.panels.island.offsetScale) + root.borderThickness
    }

    R {
        id: sessionRegion

        panel: root.panels.sessionWrapper
        x: root.win.width - width
        width: root.panelWidth(panel) * (1 - root.panels.session.offsetScale) + root.borderThickness + sidebarRegion.width
    }

    R {
        id: sidebarRegion

        panel: root.panels.sidebar
        x: root.win.width - width
        width: root.panelWidth(panel) * (1 - root.panels.sidebar.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.osdWrapper
        x: root.win.width - width
        width: root.panelWidth(panel) * (1 - root.panels.osd.offsetScale) + root.borderThickness + sessionRegion.width
    }

    R {
        panel: root.panels.notifications
        y: 0
        height: root.panelHeight(panel) + root.borderThickness
    }

    R {
        panel: root.panels.utilities
        y: root.win.height - height
        height: root.panelHeight(panel) * (1 - root.panels.utilities.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.popoutsWrapper
        width: root.panelWidth(panel) * (1 - root.panels.popoutsWrapper.offsetScale)
    }

    component R: Region {
        required property Item panel

        x: panel.x + root.bar.implicitWidth
        y: panel.y + root.borderThickness
        width: root.panelWidth(panel)
        height: root.panelHeight(panel)
        intersection: Intersection.Subtract
    }
}
