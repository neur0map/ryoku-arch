pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Singleton {
    id: root

    property alias enabled: props.enabled
    readonly property alias enabledSince: props.enabledSince
    property bool syncingFromHelper

    onEnabledChanged: {
        if (enabled)
            props.enabledSince = new Date();

        if (!syncingFromHelper)
            (enabled ? startProc : stopProc).running = true;
    }

    function setEnabledFromHelper(value: bool): void {
        syncingFromHelper = true;
        props.enabled = value;
        syncingFromHelper = false;

        if (value && isNaN(props.enabledSince.getTime()))
            props.enabledSince = new Date();
    }

    PersistentProperties {
        id: props

        property bool enabled
        property date enabledSince

        reloadableId: "idleInhibitor"
    }

    Component.onCompleted: {
        restoreProc.running = true;
    }

    Process {
        id: restoreProc

        command: ["ryoku-cmd-caffeine", "restore"]
        onExited: {
            statusProc.running = true;
        }
    }

    Process {
        id: statusProc

        command: ["ryoku-cmd-caffeine", "status"]
        onExited: code => {
            root.setEnabledFromHelper(code === 0);
        }
    }

    Process {
        id: startProc

        command: ["ryoku-cmd-caffeine", "start"]
        onExited: code => {
            root.setEnabledFromHelper(code === 0);
        }
    }

    Process {
        id: stopProc

        command: ["ryoku-cmd-caffeine", "stop"]
        onExited: {
            root.setEnabledFromHelper(false);
        }
    }

    IdleInhibitor {
        enabled: props.enabled
        window: PanelWindow {
            implicitWidth: 0
            implicitHeight: 0
            color: "transparent"
            mask: Region {}
        }
    }

    IpcHandler {
        function isEnabled(): bool {
            return props.enabled;
        }

        function toggle(): void {
            props.enabled = !props.enabled;
        }

        function enable(): void {
            props.enabled = true;
        }

        function disable(): void {
            props.enabled = false;
        }

        target: "idleInhibitor"
    }
}
