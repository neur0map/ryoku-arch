import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku
import Ryoku.Config
import qs.components.misc
import qs.services

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false

    function openControlCenter(): void {
        if (root.hasFullscreen)
            return;

        const visibilities = Visibilities.getForActive();
        visibilities.launcher = false;
        visibilities.dashboard = false;
        visibilities.island = false;
        visibilities.obsidian = false;
        visibilities.utilities = false;
        visibilities.settings = true;
    }

    function closeControlCenter(): void {
        const visibilities = Visibilities.getForActive();
        visibilities.settings = false;
    }

    function toggleControlCenter(): void {
        if (root.hasFullscreen)
            return;

        const visibilities = Visibilities.getForActive();
        if (visibilities.settings) {
            closeControlCenter();
        } else {
            openControlCenter();
        }
    }

    CustomShortcut {

        name: "controlCenter"
        description: "Open control center"
        onPressed: root.toggleControlCenter()
    }


    CustomShortcut {

        name: "showall"
        description: "Toggle launcher, top island and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            const showAll = !(v.launcher || v.island || v.osd || v.utilities);
            v.launcher = v.osd = v.utilities = showAll;
            v.island = Config.dashboard.enabled && showAll;
            v.dashboard = false;
        }
    }


    CustomShortcut {

        name: "dashboard"
        description: "Toggle top island"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            if (!Config.dashboard.enabled) {
                visibilities.island = false;
                return;
            }
            const nextIsland = !visibilities.island;
            visibilities.dashboard = false;
            if (nextIsland)
                visibilities.settings = false;
            visibilities.island = nextIsland;
        }
    }


    CustomShortcut {

        name: "session"
        description: "Toggle session menu"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.session = !visibilities.session;
        }
    }


    CustomShortcut {

        name: "launcher"
        description: "Toggle launcher"
        onPressed: root.launcherInterrupted = false
        onReleased: {
            if (!root.launcherInterrupted && !root.hasFullscreen) {
                const visibilities = Visibilities.getForActive();
                visibilities.launcher = !visibilities.launcher;
            }
            root.launcherInterrupted = false;
        }
    }


    CustomShortcut {

        name: "launcherInterrupt"
        description: "Interrupt launcher keybind"
        onPressed: root.launcherInterrupted = true
    }


    CustomShortcut {

        name: "sidebar"
        description: "Toggle sidebar"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.sidebar = !visibilities.sidebar;
        }
    }


    CustomShortcut {

        name: "utilities"
        description: "Toggle utilities"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const visibilities = Visibilities.getForActive();
            visibilities.utilities = !visibilities.utilities;
        }
    }

    IpcHandler {
        function toggle(drawer: string): void {
            const fp = Visibilities.framePluginsForActive();
            if (fp && fp.panelById(drawer)) {
                if (root.hasFullscreen)
                    return;
                fp.toggle(drawer);
                return;
            }
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard", "island", "settings", "obsidian"].includes(drawer))
                    return;
                const visibilities = Visibilities.getForActive();
                if (drawer === "dashboard") {
                    if (!Config.dashboard.enabled) {
                        visibilities.island = false;
                        return;
                    }
                    const nextIsland = !visibilities.island;
                    visibilities.dashboard = false;
                    if (nextIsland)
                        visibilities.settings = false;
                    visibilities.island = nextIsland;
                } else if (drawer === "obsidian") {
                    const nextObsidian = !visibilities.obsidian;
                    if (nextObsidian) {
                        visibilities.settings = false;
                        visibilities.dashboard = false;
                        visibilities.island = false;
                        fp?.closeAll();
                    }
                    visibilities.obsidian = nextObsidian;
                } else {
                    if (drawer === "island" && !Config.dashboard.enabled) {
                        visibilities.island = false;
                        return;
                    }
                    if (drawer === "island" && !visibilities.island)
                        visibilities.settings = false;
                    visibilities[drawer] = !visibilities[drawer];
                }
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            const keys = Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean");
            const fp = Visibilities.framePluginsForActive();
            if (fp)
                for (let i = 0; i < fp.panels.length; i++)
                    keys.push(fp.panels[i].pluginId);
            return keys.join("\n");
        }

        target: "drawers"
    }

    // RYOKU: open the dedicated, image-capable clipboard overlay (Super+V). The
    // history is captured by ClipboardService into clipboard.db; the overlay hosts
    // the dashboard's ClipboardTab via qs.modules.clipboard.
    IpcHandler {
        function open(): void {
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            if (!v)
                return;
            v.settings = false;
            v.launcher = false;
            v.island = false;
            v.clipboard = true;
        }

        function close(): void {
            const v = Visibilities.getForActive();
            if (v)
                v.clipboard = false;
        }

        function toggle(): void {
            const v = Visibilities.getForActive();
            if (!v)
                return;
            if (v.clipboard)
                v.clipboard = false;
            else
                open();
        }

        target: "clipboard"
    }

    IpcHandler {
        function open(): void {
            root.openControlCenter();
        }

        function close(): void {
            root.closeControlCenter();
        }

        function toggle(): void {
            root.toggleControlCenter();
        }

        target: "controlCenter"
    }

    IpcHandler {
        function toggleEdit(): void {
            Visibilities.widgetEditMode = !Visibilities.widgetEditMode;
        }

        function editOn(): void {
            Visibilities.widgetEditMode = true;
        }

        function editOff(): void {
            Visibilities.widgetEditMode = false;
        }

        target: "widgets"
    }

    IpcHandler {
        function info(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Info);
        }

        function success(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Success);
        }

        function warn(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Warning);
        }

        function error(title: string, message: string, icon: string): void {
            Toaster.toast(title, message, icon, Toast.Error);
        }

        target: "toaster"
    }

    LoggingCategory {
        id: lc

        name: "ryoku.qml.shortcuts"
        defaultLogLevel: LoggingCategory.Info
    }
}
