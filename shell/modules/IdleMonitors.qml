pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Ryoku.Config
import qs.services
import qs.noctalia.Services.Power

Scope {
    id: root

    // Honour BOTH keep-awake sources: the ryoku island/utilities toggle (IdleInhibitor)
    // and the noctalia bar/control-center widget (IdleInhibitorService). The latter only
    // runs systemd-inhibit (its native Wayland inhibitor lives in MainScreen, which ryoku
    // does not load), so without this gate its toggle would not stop dpms/screensaver/lock.
    readonly property bool enabled: !IdleInhibitor.enabled && !IdleInhibitorService.isInhibited && (!GlobalConfig.general.idle.inhibitWhenAudio || !Players.list.some(p => p.isPlaying))

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
