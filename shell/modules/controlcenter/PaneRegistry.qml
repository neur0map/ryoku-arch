pragma Singleton

import QtQuick

QtObject {
    id: root

    readonly property list<QtObject> panes: [
        QtObject {
            readonly property string id: "network"
            readonly property string label: "network"
            readonly property string icon: "router"
            readonly property string group: "system"
            readonly property string description: "Wi-Fi, Ethernet, and VPN connections"
            readonly property string component: "network/NetworkingPane.qml"
        },
        QtObject {
            readonly property string id: "bluetooth"
            readonly property string label: "bluetooth"
            readonly property string icon: "settings_bluetooth"
            readonly property string group: "system"
            readonly property string description: "Bluetooth devices and adapter state"
            readonly property string component: "bluetooth/BtPane.qml"
        },
        QtObject {
            readonly property string id: "audio"
            readonly property string label: "audio"
            readonly property string icon: "volume_up"
            readonly property string group: "system"
            readonly property string description: "Speakers, microphones, and volume routing"
            readonly property string component: "audio/AudioPane.qml"
        },
        QtObject {
            readonly property string id: "appearance"
            readonly property string label: "appearance"
            readonly property string icon: "palette"
            readonly property string group: "interface"
            readonly property string description: "Theme, fonts, wallpaper, and surface tuning"
            readonly property string component: "appearance/AppearancePane.qml"
        },
        QtObject {
            readonly property string id: "taskbar"
            readonly property string label: "taskbar"
            readonly property string icon: "task_alt"
            readonly property string group: "interface"
            readonly property string description: "Bar layout, status icons, workspaces, and popouts"
            readonly property string component: "taskbar/TaskbarPane.qml"
        },
        QtObject {
            readonly property string id: "notifications"
            readonly property string label: "notifications"
            readonly property string icon: "notifications"
            readonly property string group: "workflow"
            readonly property string description: "Notification behavior and toast preferences"
            readonly property string component: "notifications/NotificationsPane.qml"
        },
        QtObject {
            readonly property string id: "launcher"
            readonly property string label: "launcher"
            readonly property string icon: "apps"
            readonly property string group: "workflow"
            readonly property string description: "Launcher behavior, favorites, hidden apps, and search"
            readonly property string component: "launcher/LauncherPane.qml"
        },
        QtObject {
            readonly property string id: "dashboard"
            readonly property string label: "dashboard"
            readonly property string icon: "dashboard"
            readonly property string group: "interface"
            readonly property string description: "Dashboard cards, performance resources, and hover behavior"
            readonly property string component: "dashboard/DashboardPane.qml"
        },
        QtObject {
            readonly property string id: "about"
            readonly property string label: "about"
            readonly property string icon: "info"
            readonly property string group: "about"
            readonly property string description: "Version, updates, diagnostics, and credits"
            readonly property string component: "about/AboutPane.qml"
        }
    ]

    readonly property list<string> groups: ["system", "interface", "workflow", "about"]
    readonly property int count: panes.length

    readonly property var labels: {
        const result = [];
        for (let i = 0; i < panes.length; i++) {
            result.push(panes[i].label);
        }
        return result;
    }

    function getByIndex(index: int): var {
        if (index >= 0 && index < panes.length) {
            return panes[index];
        }
        return null;
    }

    function getIndexByLabel(label: string): int {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].label === label) {
                return i;
            }
        }
        return -1;
    }

    function getByLabel(label: string): var {
        const index = getIndexByLabel(label);
        return getByIndex(index);
    }

    function getById(id: string): var {
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].id === id) {
                return panes[i];
            }
        }
        return null;
    }

    function getByGroup(group: string): var {
        const result = [];
        for (let i = 0; i < panes.length; i++) {
            if (panes[i].group === group)
                result.push(panes[i]);
        }
        return result;
    }

    function groupLabel(group: string): string {
        if (group === "system")
            return "System";
        if (group === "interface")
            return "Interface";
        if (group === "workflow")
            return "Workflow";
        if (group === "about")
            return "About";
        return group;
    }

    function groupIcon(group: string): string {
        if (group === "system")
            return "devices";
        if (group === "interface")
            return "palette";
        if (group === "workflow")
            return "bolt";
        if (group === "about")
            return "info";
        return "settings";
    }

    function groupDescription(group: string): string {
        if (group === "system")
            return "Hardware, connections, and audio";
        if (group === "interface")
            return "Shell visuals and surface layout";
        if (group === "workflow")
            return "Alerts, launcher, and daily flow";
        if (group === "about")
            return "Version, updates, and credits";
        return "";
    }
}
