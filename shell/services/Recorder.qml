pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Ryoku recorder service. Drives ryoku-cmd-screenrecord, which records with
// gpu-screen-recorder and falls back to wf-recorder on multi-GPU machines where
// the display is driven by a different GPU than gpu-screen-recorder targets.
//
// State is reconciled against the real recorder process: a recorder that fails
// to launch (or exits on its own) can no longer leave a phantom "recording"
// timer running in the UI.
Singleton {
    id: root

    readonly property alias running: props.running
    readonly property alias paused: props.paused
    readonly property alias elapsed: props.elapsed

    // Active capture backend: "gsr", "wf", or "" when idle.
    readonly property alias backend: props.backend
    // Only gpu-screen-recorder supports pause/resume.
    readonly property bool canPause: props.backend === "gsr"

    property list<string> startArgs

    function start(extraArgs = []): void {
        root.startArgs = extraArgs;
        Quickshell.execDetached(["ryoku-cmd-screenrecord", ...root.startArgs]);
        props.running = true;
        props.paused = false;
        props.elapsed = 0;
        confirmTimer.restart();
    }

    function stop(): void {
        Quickshell.execDetached(["ryoku-cmd-screenrecord", "--stop"]);
        props.running = false;
        props.paused = false;
    }

    function togglePause(): void {
        if (!root.canPause)
            return;
        Quickshell.execDetached(["ryoku-cmd-screenrecord", "--pause"]);
        props.paused = !props.paused;
    }

    PersistentProperties {
        id: props

        property bool running: false
        property bool paused: false
        property real elapsed: 0 // Might get too large for int
        property string backend: ""

        reloadableId: "recorder"
    }

    // Reconcile UI state with the real recorder process and report which backend
    // owns the recording (so the UI can hide pause when it isn't supported).
    Process {
        id: statusProc

        running: true
        command: ["sh", "-c", "if pidof gpu-screen-recorder >/dev/null 2>&1; then echo gsr; elif pidof wf-recorder >/dev/null 2>&1; then echo wf; else echo idle; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const detected = text.trim();
                const alive = detected === "gsr" || detected === "wf";
                props.running = alive;
                props.backend = alive ? detected : "";
                if (!alive)
                    props.paused = false;
            }
        }
    }

    // Confirm the recorder actually came up shortly after a start request, so a
    // failed launch clears the optimistic running state instead of counting up
    // forever.
    Timer {
        id: confirmTimer

        interval: 2500
        onTriggered: statusProc.running = true
    }

    // Keep reconciling while a recording is believed active to catch external
    // stops, crashes, or a backend that exited on its own.
    Timer {
        interval: 2000
        repeat: true
        running: props.running
        onTriggered: statusProc.running = true
    }

    Connections {
        enabled: props.running && !props.paused
        function onSecondsChanged(): void {
            props.elapsed++;
        }

        target: Time
    }
}
