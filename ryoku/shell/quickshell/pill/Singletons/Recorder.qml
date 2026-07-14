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
    // studio capture records with gpu-screen-recorder (below) and hands the clip
    // to the ryomotion editor; our island is the toolbar and drives start/stop.
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

    // studio uses gpu-screen-recorder + a cursor track (this wrapper), then opens
    // the clip in the ryomotion editor; a bare name wouldn't resolve on PATH.
    readonly property string studioScript: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/ryoku-cmd-studiorecord"

    // region capture: the box the user drew as gsr's "WxH+X+Y" (logical coords),
    // "" = full monitor. slurp must launch detached (a managed Process gets its
    // session killed before it can grab the seat), so it writes the box to a state
    // file the FileView reads back -- QML (the overlay) and the recorder scripts
    // then share one geometry. regionPicking gates it so a fresh pick applies but a
    // stale file left from a past session does not.
    property string regionGeom: ""
    property bool regionPicking: false
    readonly property string regionFilePath: (Quickshell.env("RYOKU_STATE_PATH") || (Quickshell.env("HOME") + "/.local/state/ryoku")) + "/region-pick"
    function pickRegion() {
        root.regionPicking = true;
        Quickshell.execDetached(["sh", "-c",
            "mkdir -p \"$(dirname '" + root.regionFilePath + "')\"; "
            + "g=$(slurp -f '%wx%h+%x+%y' 2>/dev/null); "
            + "printf '%s' \"$g\" > '" + root.regionFilePath + ".tmp'; "
            + "mv '" + root.regionFilePath + ".tmp' '" + root.regionFilePath + "'"]);
    }
    FileView {
        id: regionFile
        path: root.regionFilePath
        blockLoading: true
        atomicWrites: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            if (!root.regionPicking)
                return;
            root.regionPicking = false;
            var g = (regionFile.text() || "").trim();
            root.regionGeom = /^\d+x\d+\+\d+\+\d+$/.test(g) ? g : "";
        }
    }

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
    // studio: record with gpu-screen-recorder + a cursor track, then open the clip
    // in the ryomotion editor (its auto-zoom reads the cursor track we synthesise).
    // Tracked so our stop can signal the wrapper; anyActive keeps the island up
    // until the gsr poll confirms the capture.
    function startStudio(desktopAudio, mic, regionGeom) {
        var args = [root.studioScript];
        if (regionGeom) { args.push("--region", "--geometry", regionGeom); }
        if (desktopAudio) args.push("--with-desktop-audio");
        if (mic) args.push("--with-microphone-audio");
        studioProc.command = args;
        studioProc.running = true;
        root.studioActive = true;
        root.paused = false;
        root.backend = "studio";
        root.startedAt = Math.floor(Date.now() / 1000);
        root.elapsedSec = 0;
    }
    function stopStudio() {
        // SIGTERM the wrapper (not gsr): it stops the capture, writes the cursor
        // sidecar, and opens the editor, so it needs to run its own shutdown.
        if (studioProc.running && studioProc.processId > 0)
            Quickshell.execDetached(["kill", "-TERM", String(studioProc.processId)]);
        root.studioActive = false;
        root.paused = false;
        root.backend = "";
        root.startedAt = 0;
        root.elapsedSec = 0;
    }

    Process {
        id: studioProc
        onRunningChanged: {
            // the studio wrapper exited on its own (gsr failed to start, or it
            // finished and opened the editor): don't strand the island counting up.
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

    // reconcile cadence: poll hard (2s) only while a capture is live, so an
    // external stop or crash can't strand the island; idle we poll slowly (30s),
    // enough to catch a capture started outside the shell without spawning a
    // pgrep subprocess every 2s around the clock.
    Timer {
        interval: root.anyActive ? 2000 : 30000
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
