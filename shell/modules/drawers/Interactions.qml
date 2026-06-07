import QtQuick
import QtQuick.Controls
import Quickshell
import Ryoku.Config
import qs.components
import qs.components.controls
import qs.modules.bar as Bar
import qs.modules.bar.popouts as BarPopouts

CustomMouseArea {
    id: root

    required property ShellScreen screen
    required property BarPopouts.Wrapper popouts
    required property DrawerVisibilities visibilities
    required property Panels panels
    required property Bar.BarWrapper bar
    required property real borderThickness
    required property bool fullscreen

    property point dragStart
    property bool dashboardShortcutActive
    property bool islandShortcutActive
    property bool obsidianShortcutActive
    property bool osdShortcutActive
    property bool utilitiesShortcutActive
    readonly property real frameActivationWidth: Math.min(220, Math.max(120, width * 0.12))

    function panelWidth(panel: Item): real {
        return Math.max(panel.width, panel.implicitWidth ?? 0);
    }

    function panelHeight(panel: Item): real {
        return Math.max(panel.height, panel.implicitHeight ?? 0);
    }

    function inPanelBounds(panel: Item, x: real, y: real): bool {
        const local = panel.mapFromItem(root, x, y);
        const visibleHeight = root.panelHeight(panel) * (1 - (panel.offsetScale ?? 0));
        return local.x >= -Config.border.rounding
            && local.x <= root.panelWidth(panel) + Config.border.rounding
            && local.y >= -Config.border.rounding
            && local.y <= visibleHeight + Config.border.rounding;
    }

    function closeSettingsIfOutside(x: real, y: real): bool {
        if (visibilities.settings && !inPanelBounds(panels.settings, x, y)) {
            visibilities.settings = false;
            return true;
        }
        return false;
    }

    function withinPanelHeight(panel: Item, x: real, y: real): bool {
        const panelY = root.borderThickness + panel.y;
        return y >= panelY - Config.border.rounding && y <= panelY + root.panelHeight(panel) + Config.border.rounding;
    }

    function withinPanelWidth(panel: Item, x: real, y: real): bool {
        const panelX = bar.implicitWidth + panel.x;
        return x >= panelX - Config.border.rounding && x <= panelX + root.panelWidth(panel) + Config.border.rounding;
    }

    function inLeftPanel(panel: Item, x: real, y: real): bool {
        return x < bar.implicitWidth + panel.x + root.panelWidth(panel) && withinPanelHeight(panel, x, y);
    }

    function inRightPanel(panel: Item, x: real, y: real): bool {
        return x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panel.x) && withinPanelHeight(panel, x, y);
    }

    function inTopPanel(panel: Item, x: real, y: real): bool {
        const panelHeight = root.panelHeight(panel) * (1 - (panel.offsetScale ?? 0));
        return y < Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) && withinPanelWidth(panel, x, y);
    }

    function inFramePanel(panel: var, x: real, y: real): bool {
        const edge = panel.edge || "top";
        const align = panel.align || "end";

        if ((panel.offsetScale ?? 1) < 1) {
            if (edge === "bottom" ? inBottomPanel(panel, x, y) : inTopPanel(panel, x, y))
                return true;
        }

        const stripH = panel.activationHeight > 0 ? panel.activationHeight : Math.max(Config.border.minThickness, Config.border.thickness);
        const inStrip = edge === "bottom" ? y > height - stripH : y < stripH;
        if (!inStrip)
            return false;

        // The author can size the hover zone via frame.activationWidth; otherwise fall back to
        // the full strip width (panelWidth is 0 while the popout's content is lazy-loaded).
        const pw = root.panelWidth(panel);
        const activationWidth = panel.activationWidth > 0 ? panel.activationWidth : (pw > 0 ? Math.min(root.frameActivationWidth, pw) : root.frameActivationWidth);
        if (align === "start")
            return x >= bar.implicitWidth - Config.border.rounding && x <= bar.implicitWidth + activationWidth + Config.border.rounding;
        if (align === "center") {
            const cx = bar.implicitWidth + (width - bar.implicitWidth) / 2;
            return x >= cx - activationWidth / 2 && x <= cx + activationWidth / 2;
        }
        return x >= width - activationWidth - Config.border.rounding && x <= width + Config.border.rounding;
    }

    function inObsidianPanel(panel: Item, x: real, y: real): bool {
        if ((panel.offsetScale ?? 1) < 1 && inLeftPanel(panel, x, y))
            return true;

        return x <= bar.implicitWidth + Config.border.rounding
            && bar.isClockHover(y);
    }

    function inBottomPanel(panel: Item, x: real, y: real, isCorner = false): bool {
        const panelHeight = root.panelHeight(panel) * (1 - (panel.offsetScale ?? 0));
        return y > height - Math.max(Config.border.minThickness, Config.border.thickness + panelHeight) - (isCorner ? Config.border.rounding : 0) && withinPanelWidth(panel, x, y);
    }

    function onWheel(event: WheelEvent): void {
        if (fullscreen)
            return;
        if (event.x < bar.implicitWidth) {
            bar.handleWheel(event.y, event.angleDelta);
        }
    }

    anchors.fill: parent
    acceptedButtons: fullscreen ? Qt.NoButton : Qt.AllButtons
    hoverEnabled: true

    onPressed: event => {
        dragStart = Qt.point(event.x, event.y);
        if (closeSettingsIfOutside(event.x, event.y)) {
            event.accepted = true;
        } else if (visibilities.settings) {
            event.accepted = false;
        }
    }
    onContainsMouseChanged: {
        if (!containsMouse) {
            // Only hide if not activated by shortcut
            if (!osdShortcutActive) {
                visibilities.osd = false;
                root.panels.osd.hovered = false;
            }

            if (!dashboardShortcutActive)
                visibilities.dashboard = false;

            if (!islandShortcutActive)
                visibilities.island = false;

            panels.framePlugins.clearHover();

            if (!obsidianShortcutActive)
                visibilities.obsidian = false;

            if (!utilitiesShortcutActive)
                visibilities.utilities = false;

            if (!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) {
                popouts.hasCurrent = false;
                bar.closeTray();
            }

            if (Config.bar.showOnHover)
                bar.isHovered = false;
        }
    }

    onPositionChanged: event => {
        if (popouts.isDetached)
            return;

        const x = event.x;
        const y = event.y;
        const dragX = x - dragStart.x;
        const dragY = y - dragStart.y;

        if (fullscreen) {
            root.panels.osd.hovered = inRightPanel(panels.osdWrapper, x, y);
            return;
        }

        // Show bar in non-exclusive mode on hover
        if (!visibilities.bar && Config.bar.showOnHover && x < bar.clampedWidth)
            bar.isHovered = true;

        // Show/hide bar on drag
        if (pressed && dragStart.x < bar.clampedWidth) {
            if (dragX > Config.bar.dragThreshold)
                visibilities.bar = true;
            else if (dragX < -Config.bar.dragThreshold)
                visibilities.bar = false;
        }

        if (panels.sidebar.offsetScale === 1) {
            // Show osd on hover
            const showOsd = inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                visibilities.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            const showSidebar = pressed && dragStart.x > Math.min(width - Config.border.minThickness, bar.implicitWidth + panels.sidebar.x);

            // Show/hide session on drag
            if (pressed && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;

                // Show sidebar on drag if in session area and session is nearly fully visible
                if (showSidebar && panels.session.offsetScale <= 0 && dragX < -Config.sidebar.dragThreshold)
                    visibilities.sidebar = true;
            } else if (showSidebar && dragX < -Config.sidebar.dragThreshold) {
                // Show sidebar on drag if not in session area
                visibilities.sidebar = true;
            }
        } else {
            const outOfSidebar = x < width - panels.sidebar.width * (1 - panels.sidebar.offsetScale);
            // Show osd on hover
            const showOsd = outOfSidebar && inRightPanel(panels.osdWrapper, x, y);

            // Always update visibility based on hover if not in shortcut mode
            if (!osdShortcutActive) {
                visibilities.osd = showOsd;
                root.panels.osd.hovered = showOsd;
            } else if (showOsd) {
                // If hovering over OSD area while in shortcut mode, transition to hover control
                osdShortcutActive = false;
                root.panels.osd.hovered = true;
            }

            // Show/hide session on drag
            if (pressed && outOfSidebar && inRightPanel(panels.sessionWrapper, dragStart.x, dragStart.y) && withinPanelHeight(panels.sessionWrapper, x, y)) {
                if (dragX < -Config.session.dragThreshold)
                    visibilities.session = true;
                else if (dragX > Config.session.dragThreshold)
                    visibilities.session = false;
            }

            // Hide sidebar on drag
            if (pressed && inRightPanel(panels.sidebar, dragStart.x, 0) && dragX > Config.sidebar.dragThreshold)
                visibilities.sidebar = false;
        }

        // Top-center dashboard hover is replaced by the embedded island.
        const showIsland = !visibilities.settings && Config.dashboard.enabled && Config.dashboard.showOnHover && inTopPanel(panels.island, x, y);
        visibilities.dashboard = false;

        if (!islandShortcutActive) {
            visibilities.island = showIsland;
        } else if (showIsland) {
            // If hovering over island area while in shortcut mode, transition to hover control.
            islandShortcutActive = false;
        }

        // Show/hide island on the old dashboard drag gesture (touchscreen path).
        if (!visibilities.settings && Config.dashboard.enabled && pressed && inTopPanel(panels.island, dragStart.x, dragStart.y) && withinPanelWidth(panels.island, x, y)) {
            if (dragY > Config.dashboard.dragThreshold)
                visibilities.island = true;
            else if (dragY < -Config.dashboard.dragThreshold)
                visibilities.island = false;
        }

        // Show installed frame plugins on their frame-corner hover.
        if (!visibilities.settings) {
            const framePanels = panels.framePlugins.panels;
            let frameHit = "";
            for (let i = 0; i < framePanels.length; i++) {
                if (inFramePanel(framePanels[i], x, y)) {
                    frameHit = framePanels[i].pluginId;
                    break;
                }
            }
            panels.framePlugins.hover(frameHit);
            if (frameHit.length > 0) {
                visibilities.dashboard = false;
                visibilities.island = false;
                visibilities.obsidian = false;
            }
        }

        // Show Obsidian notes/calendar on the taskbar-side corner hover.
        const showObsidian = !visibilities.settings && inObsidianPanel(panels.obsidian, x, y);
        if (!obsidianShortcutActive) {
            visibilities.obsidian = showObsidian;
        } else if (showObsidian) {
            obsidianShortcutActive = false;
        }

        // Show utilities on hover
        const showUtilities = inBottomPanel(panels.utilities, x, y, true);

        // Always update visibility based on hover if not in shortcut mode
        if (!utilitiesShortcutActive) {
            visibilities.utilities = showUtilities;
        } else if (showUtilities) {
            // If hovering over utilities area while in shortcut mode, transition to hover control
            utilitiesShortcutActive = false;
        }

        // Show popouts on hover
        if (x < bar.implicitWidth) {
            if (!showObsidian)
                bar.checkPopout(y);
        } else if ((!popouts.currentName.startsWith("traymenu") || ((popouts.current as StackView)?.depth ?? 0) <= 1) && !inLeftPanel(panels.popoutsWrapper, x, y)) {
            popouts.hasCurrent = false;
            bar.closeTray();
        }
    }

    // Monitor individual visibility changes
    Connections {
        function onLauncherChanged() {
            // If launcher is hidden, clear shortcut flags for dashboard and OSD
            if (!root.visibilities.launcher) {
                root.dashboardShortcutActive = false;
                root.osdShortcutActive = false;
                root.panels.framePlugins.shortcutActive = false;
                root.obsidianShortcutActive = false;
                root.utilitiesShortcutActive = false;

                // Also hide dashboard and OSD if they're not being hovered
                const inDashboardArea = root.inTopPanel(root.panels.dashboard, root.mouseX, root.mouseY);
                const inObsidianArea = root.inObsidianPanel(root.panels.obsidian, root.mouseX, root.mouseY);
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);

                if (!inDashboardArea) {
                    root.visibilities.dashboard = false;
                }
                const fps = root.panels.framePlugins.panels;
                let frameHovered = "";
                for (let i = 0; i < fps.length; i++) {
                    if (root.inFramePanel(fps[i], root.mouseX, root.mouseY)) {
                        frameHovered = fps[i].pluginId;
                        break;
                    }
                }
                root.panels.framePlugins.hover(frameHovered);
                if (!inObsidianArea) {
                    root.visibilities.obsidian = false;
                }
                if (!inOsdArea) {
                    root.visibilities.osd = false;
                    root.panels.osd.hovered = false;
                }
            }
        }

        function onDashboardChanged() {
            if (root.visibilities.dashboard) {
                // The top dashboard slot is unplugged for this live island experiment.
                root.visibilities.settings = false;
                root.visibilities.dashboard = false;
                root.visibilities.island = Config.dashboard.enabled;
                root.panels.framePlugins.closeAll();
            } else {
                root.dashboardShortcutActive = false;
            }
        }

        function onIslandChanged() {
            if (root.visibilities.island && !Config.dashboard.enabled) {
                root.visibilities.island = false;
                return;
            }
            if (root.visibilities.island) {
                root.visibilities.settings = false;
                root.visibilities.dashboard = false;
                root.panels.framePlugins.closeAll();
                const inIslandArea = root.inTopPanel(root.panels.island, root.mouseX, root.mouseY);
                if (!inIslandArea)
                    root.islandShortcutActive = true;
            } else {
                root.islandShortcutActive = false;
            }
        }

        function onSettingsChanged() {
            if (root.visibilities.settings) {
                root.visibilities.dashboard = false;
                root.visibilities.island = false;
                root.panels.framePlugins.closeAll();
                root.visibilities.obsidian = false;
                root.dashboardShortcutActive = false;
                root.islandShortcutActive = false;
                root.obsidianShortcutActive = false;
            }
        }

        function onObsidianChanged() {
            if (root.visibilities.obsidian) {
                root.visibilities.dashboard = false;
                root.visibilities.island = false;
                root.visibilities.settings = false;
                root.panels.framePlugins.closeAll();
                root.dashboardShortcutActive = false;
                root.islandShortcutActive = false;
                const inObsidianArea = root.inObsidianPanel(root.panels.obsidian, root.mouseX, root.mouseY);
                if (!inObsidianArea)
                    root.obsidianShortcutActive = true;
            } else {
                root.obsidianShortcutActive = false;
            }
        }

        function onOsdChanged() {
            if (root.visibilities.osd) {
                // OSD became visible, immediately check if this should be shortcut mode
                const inOsdArea = root.inRightPanel(root.panels.osdWrapper, root.mouseX, root.mouseY);
                if (!inOsdArea) {
                    root.osdShortcutActive = true;
                }
            } else {
                // OSD hidden, clear shortcut flag
                root.osdShortcutActive = false;
            }
        }

        function onUtilitiesChanged() {
            if (root.visibilities.utilities) {
                // Utilities became visible, immediately check if this should be shortcut mode
                const inUtilitiesArea = root.inBottomPanel(root.panels.utilities, root.mouseX, root.mouseY);
                if (!inUtilitiesArea) {
                    root.utilitiesShortcutActive = true;
                }
            } else {
                // Utilities hidden, clear shortcut flag
                root.utilitiesShortcutActive = false;
            }
        }

        target: root.visibilities
    }
}
