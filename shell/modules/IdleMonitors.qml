pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Wayland as QsWl
import Ryoku.Config
import qs.services

Scope {
    id: root

    // Single keep-awake source of truth: the qs.services IdleInhibitor singleton.
    // Quickshell.Wayland ALSO exports an IdleInhibitor type, so that import is
    // aliased (QsWl); otherwise `IdleInhibitor` resolves to the Wayland type and
    // `IdleInhibitor.enabled` is undefined, leaving the gate permanently open so
    // keep-awake never disables idle.
    // inhibitWhenAudio inhibits only on real audio PLAYBACK (an output stream,
    // media.class "Stream/Output/Audio"), ignoring capture streams (the shell's own
    // Cava visualiser / beat-tracker hold a permanent input capture). Genuine
    // no-idle apps (fullscreen video) are handled per-monitor by respectInhibitors.
    readonly property bool enabled: !IdleInhibitor.enabled && (!GlobalConfig.general.idle.inhibitWhenAudio || !Audio.streams.some(s => (s.properties["media.class"] || "").indexOf("Output") !== -1))

    // When idle is disabled (keep-awake turned on, or audio starts), tear down a
    // screensaver that is still up: its own dismiss only catches keyboard and focus
    // changes, so a mouse-click on the bar to enable keep-awake would otherwise
    // leave it covering the screen.
    onEnabledChanged: if (!enabled) Quickshell.execDetached(["sh", "-c", "pkill -f org.ryoku.screensaver 2>/dev/null; pkill -x tte 2>/dev/null"])

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

        QsWl.IdleMonitor {
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
                    // fullscreen screensaver window itself resets ext_idle, which would
                    // instantly trigger this return action and close it (a self-kill
                    // loop that made the screensaver never appear).
                    root.handleIdleAction(modelData.returnAction);
                }
            }
        }
    }
}
