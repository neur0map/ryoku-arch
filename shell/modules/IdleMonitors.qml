pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Ryoku.Config
import qs.services

Scope {
    id: root

    readonly property bool enabled: !IdleInhibitor.enabled && (!GlobalConfig.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying))

    function handleIdleAction(action: var): void {
        if (!action)
            return;

        if (action === "lock")
            Quickshell.execDetached(["loginctl", "lock-session"]);
        else if (action === "unlock")
            Quickshell.execDetached(["loginctl", "unlock-session"]);
        else if (typeof action === "string")
            Hypr.dispatch(action);
        else
            Quickshell.execDetached(action);
    }

    Variants {
        model: GlobalConfig.general.idle.timeouts

        IdleMonitor {
            required property var modelData

            enabled: root.enabled && (modelData.enabled ?? true)
            timeout: modelData.timeout
            respectInhibitors: modelData.respectInhibitors ?? true
            onIsIdleChanged: root.handleIdleAction(isIdle ? modelData.idleAction : modelData.returnAction)
        }
    }
}
