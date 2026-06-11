pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland
import Ryoku.Config
import qs.services

Scope {
    id: root

    // Single keep-awake source of truth: qs.services IdleInhibitor (shared by the
    // island card and the bar/control-center widgets via IdleInhibitorService).
    // inhibitWhenAudio inhibits only on actual audio PLAYBACK — an output stream
    // (media.class "Stream/Output/Audio"), ignoring capture streams (the shell's
    // own Cava visualiser / beat-tracker hold a permanent input capture). Genuine
    // no-idle apps (fullscreen video) are handled per-monitor by respectInhibitors.
    readonly property bool enabled: !IdleInhibitor.enabled && (!GlobalConfig.general.idle.inhibitWhenAudio || !Audio.streams.some(s => (s.properties["media.class"] || "").indexOf("Output") !== -1))

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
            onIsIdleChanged: {
                if (isIdle) {
                    root.handleIdleAction(modelData.idleAction);
                } else if (modelData.kind !== "screensaver") {
                    // The screensaver dismisses itself (ryoku-cmd-screensaver reads
                    // input and checks focus). Do NOT kill it from here: opening the
                    // fullscreen screensaver window itself resets ext_idle, which
                    // would instantly trigger this return action and close it — a
                    // self-kill loop that made the screensaver never appear.
                    root.handleIdleAction(modelData.returnAction);
                }
            }
        }
    }
}
