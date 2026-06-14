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
    readonly property real frameActivationWidth: Math.min(220, Math.max(120, win.width * 0.12))
    readonly property real barClampLeft: bar.edge === "left" ? bar.clampedThickness : clampedThickness
    readonly property real barClampTop: bar.edge === "top" ? bar.clampedThickness : clampedThickness
    readonly property real barClampRight: bar.edge === "right" ? bar.clampedThickness : clampedThickness
    readonly property real barClampBottom: bar.edge === "bottom" ? bar.clampedThickness : clampedThickness
    readonly property real barInsetLeft: bar.edge === "left" ? bar.thickness : borderThickness
    readonly property real barInsetTop: bar.edge === "top" ? bar.thickness : borderThickness

    function panelWidth(panel: Item): real {
        return Math.max(panel.width, panel.implicitWidth ?? 0);
    }

    function panelHeight(panel: Item): real {
        return Math.max(panel.height, panel.implicitHeight ?? 0);
    }

    x: barClampLeft + win.dragMaskPadding
    y: barClampTop + win.dragMaskPadding
    width: win.width - barClampLeft - barClampRight - win.dragMaskPadding * 2
    height: win.height - barClampTop - barClampBottom - win.dragMaskPadding * 2
    intersection: Intersection.Xor

    R {
        panel: root.panels.dashboard
        y: 0
        height: root.panelHeight(panel) * (1 - root.panels.dashboard.offsetScale) + root.barInsetTop
    }

    R {
        panel: root.panels.settings
        y: 0
        height: root.panelHeight(panel) * (1 - root.panels.settings.offsetScale) + root.barInsetTop
    }

    FrameR {
        panel: root.panels.framePlugins.panels.length > 0 ? root.panels.framePlugins.panels[0] : null
    }

    FrameR {
        panel: root.panels.framePlugins.panels.length > 1 ? root.panels.framePlugins.panels[1] : null
    }

    FrameR {
        panel: root.panels.framePlugins.panels.length > 2 ? root.panels.framePlugins.panels[2] : null
    }

    R {
        panel: root.panels.obsidian
        y: root.win.height - height
        width: root.panelWidth(panel) * (1 - root.panels.obsidian.offsetScale) + root.borderThickness
        height: root.panelHeight(panel) * (1 - root.panels.obsidian.offsetScale) + root.borderThickness
    }

    R {
        panel: root.panels.launcher
        height: panel.height + (root.panels.launcher.openProgress > 0 ? root.borderThickness : 0)
    }

    R {
        panel: root.panels.clipboard
        height: panel.height + (root.panels.clipboard.openProgress > 0 ? root.borderThickness : 0)
    }

    R {
        panel: root.panels.island
        y: 0
        height: panel.height * (1 - root.panels.island.offsetScale) + root.barInsetTop
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
        height: root.panelHeight(panel) + root.barInsetTop
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

        x: panel.x + root.barInsetLeft
        y: panel.y + root.barInsetTop
        width: root.panelWidth(panel)
        height: root.panelHeight(panel)
        intersection: Intersection.Subtract
    }

    // Input region for a plugin frame popout: covers the author's activation zone while closed
    // (so the whole hover area opens it) and grows to the full panel as it slides in.
    component FrameR: Region {
        property var panel: null

        readonly property real vis: panel ? 1 - (panel.offsetScale ?? 1) : 0
        readonly property string edge: panel ? (panel.edge || "top") : "top"
        readonly property string align: panel ? (panel.align || "end") : "end"
        readonly property real closedW: panel ? (panel.activationWidth > 0 ? panel.activationWidth : root.frameActivationWidth) : 0
        readonly property real closedH: panel ? (panel.activationHeight > 0 ? panel.activationHeight : root.borderThickness) : 0
        readonly property real w: panel ? closedW + Math.max(0, root.panelWidth(panel) - closedW) * vis : 0
        readonly property real h: panel ? closedH + Math.max(0, root.panelHeight(panel) - closedH) * vis : 0

        x: !panel ? 0 : align === "start" ? root.barClampLeft : align === "center" ? Math.round((root.win.width - w) / 2) : root.win.width - w
        y: !panel ? 0 : edge === "bottom" ? root.win.height - h - (root.bar.edge === "bottom" ? root.bar.thickness : 0) : (root.bar.edge === "top" ? root.bar.thickness : 0)
        width: w
        height: h
        intersection: Intersection.Subtract
    }
}
