pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// screen recording state + control. drives ryoku-cmd-screenrecord
// (gpu-screen-recorder, falling back to wf-recorder on multi-GPU machines) and
// reconciles against the live process, so a failed launch or an external stop
// can't strand the UI. pause is optimistic, gsr only (wf-recorder can't pause).
// the strip chip + the utilities Record card share this one source of truth.
Singleton {
    id: root

    property bool active: false
    property bool paused: false
    // the sidebar Record button opens the floating island in its pre-record
    // chooser, where the capture toggles and the Quick / Studio / Edit actions live.
    property bool chooserOpen: false
    // studio recording runs ryomotion (the OpenScreen fork) headless: our island
    // is the toolbar, so ryomotion's own HUD stays hidden and we drive start/stop.
    property bool studioActive: false
    readonly property bool anyActive: root.active || root.studioActive
    // owning backend: "gsr" | "wf" | "" when idle.
    property string backend: ""
    readonly property bool canPause: backend === "gsr"
    property int startedAt: 0
    property int elapsedSec: 0
    property real pulse: 1
    readonly property string elapsedText: fmt(elapsedSec)

    // full path: ~/.config/hypr/scripts isn't on the shell's PATH, a bare name
    // wouldn't resolve and recording would silently never start.
    readonly property string script: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-screenrecord"

    function start(extraArgs) {
        Quickshell.execDetached([root.script, ...(extraArgs || [])]);
        root.paused = false;
        root.active = true;
        root.startedAt = Math.floor(Date.now() / 1000);
        root.elapsedSec = 0;
        confirm.restart();
    }

    function stop() {
        Quickshell.execDetached([root.script, "--stop"]);
        root.active = false;
        root.paused = false;
    }

    function togglePause() {
        if (!root.canPause)
            return;
        Quickshell.execDetached([root.script, "--pause"]);
        root.paused = !root.paused;
    }
    // studio: launch ryomotion in RYOKU_RECORD mode (HUD hidden, auto-records with
    // these options), tracked so our stop signals its exact main process. SIGUSR1
    // maps to ryomotion's tray-stop, so it finalises the file and opens the editor.
    function startStudio(desktopAudio, mic) {
        studioProc.command = ["sh", "-c",
            "command -v ryomotion >/dev/null 2>&1 || { notify-send 'Ryomotion' 'Not installed yet'; exit 0; }; "
            + "exec env RYOKU_RECORD=1"
            + " RYOKU_AUDIO=" + (desktopAudio ? "1" : "0")
            + " RYOKU_MIC=" + (mic ? "1" : "0")
            + " RYOKU_WEBCAM=0 ryomotion"];
        studioProc.running = true;
        root.studioActive = true;
        root.paused = false;
        root.backend = "studio";
        root.startedAt = Math.floor(Date.now() / 1000);
        root.elapsedSec = 0;
    }
    function stopStudio() {
        if (studioProc.running && studioProc.processId > 0)
            Quickshell.execDetached(["kill", "-USR1", String(studioProc.processId)]);
        root.studioActive = false;
        root.paused = false;
        root.backend = "";
        root.startedAt = 0;
        root.elapsedSec = 0;
    }

    Process {
        id: studioProc
        onRunningChanged: {
            // ryomotion exited before we stopped (crash, or never installed): don't
            // strand the island counting up in a studio state that isn't real.
            if (!studioProc.running && root.studioActive) {
                root.studioActive = false;
                root.backend = "";
                root.startedAt = 0;
                root.elapsedSec = 0;
            }
        }
    }

    SequentialAnimation on pulse {
        running: root.anyActive && !root.paused
        loops: Animation.Infinite
        NumberAnimation { to: 0.18; duration: 620; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1.0; duration: 620; easing.type: Easing.InOutSine }
    }

    // reconcile against the live process: surface the owning backend and clear
    // stale state when nothing's recording. pause stays optimistic while active.
    Process {
        id: poll
        // match the full command line, not comm: Linux truncates comm to 15
        // chars so "gpu-screen-recorder" (19) never matches `pgrep -x`. the [g]
        // bracket keeps this poll's own command from matching itself.
        command: ["sh", "-c", "if pgrep -f '(^|/)[g]pu-screen-recorder( |$)' >/dev/null 2>&1; then echo gsr; elif pgrep -f '(^|/)[w]f-recorder( |$)' >/dev/null 2>&1; then echo wf; else echo off; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                var b = text.trim();
                var nowActive = b === "gsr" || b === "wf";
                if (nowActive && !root.active) {
                    root.startedAt = Math.floor(Date.now() / 1000);
                    root.elapsedSec = 0;
                }
                if (!nowActive && !root.studioActive) {
                    root.startedAt = 0;
                    root.elapsedSec = 0;
                    root.pulse = 1;
                    root.paused = false;
                }
                root.active = nowActive;
                if (nowActive) root.backend = b;
                else if (!root.studioActive) root.backend = "";
            }
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!poll.running) poll.running = true
    }

    // confirm the recorder actually came up after a start; a failed launch
    // would otherwise leave the optimistic running state counting up forever.
    Timer {
        id: confirm
        interval: 2500
        onTriggered: poll.running = true
    }

    // increment, don't recompute from startedAt -- a pause freezes the clock
    // and a resume continues it.
    Timer {
        interval: 1000
        running: root.anyActive && !root.paused
        repeat: true
        onTriggered: root.elapsedSec++
    }

    function fmt(sec) {
        var s = Math.max(0, Math.round(sec));
        var h = Math.floor(s / 3600);
        var m = Math.floor((s % 3600) / 60);
        var r = s % 60;
        if (h > 0)
            return h + ":" + (m < 10 ? "0" : "") + m + ":" + (r < 10 ? "0" : "") + r;
        return m + ":" + (r < 10 ? "0" : "") + r;
    }
}
