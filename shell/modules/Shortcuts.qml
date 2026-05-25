import QtQuick
import Quickshell
import Quickshell.Io
import Ryoku
import qs.components.misc
import qs.services
import qs.modules.controlcenter

Scope {
    id: root

    property bool launcherInterrupted
    readonly property bool hasFullscreen: Hypr.focusedWorkspace?.toplevels.values.some(t => t.lastIpcObject.fullscreen > 1) ?? false


    CustomShortcut {

        name: "controlCenter"
        description: "Open control center"
        onPressed: WindowFactory.toggle()
    }


    CustomShortcut {

        name: "showall"
        description: "Toggle launcher, top island and osd"
        onPressed: {
            if (root.hasFullscreen)
                return;
            const v = Visibilities.getForActive();
            v.launcher = v.island = v.osd = v.utilities = !(v.launcher || v.island || v.osd || v.utilities);
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
            visibilities.dashboard = false;
            visibilities.island = !visibilities.island;
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
            if (list().split("\n").includes(drawer)) {
                if (root.hasFullscreen && ["launcher", "session", "dashboard", "island"].includes(drawer))
                    return;
                const visibilities = Visibilities.getForActive();
                if (drawer === "dashboard") {
                    visibilities.dashboard = false;
                    visibilities.island = !visibilities.island;
                } else {
                    visibilities[drawer] = !visibilities[drawer];
                }
            } else {
                console.warn(lc, `Drawer "${drawer}" does not exist`);
            }
        }

        function list(): string {
            const visibilities = Visibilities.getForActive();
            return Object.keys(visibilities).filter(k => typeof visibilities[k] === "boolean").join("\n");
        }

        target: "drawers"
    }

    IpcHandler {
        function open(): void {
            WindowFactory.open();
        }

        function close(): void {
            WindowFactory.close();
        }

        function toggle(): void {
            WindowFactory.toggle();
        }

        target: "controlCenter"
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
