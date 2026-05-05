pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.modules.common

Singleton {
    id: root

    property bool isRecording: false
    // Timestamp (ms since epoch) when recording started, 0 when not recording
    property real recordingStartTime: 0
    // Elapsed seconds since recording started, updated every second
    property int elapsedSeconds: 0

    onIsRecordingChanged: {
        if (isRecording) {
            recordingStartTime = Date.now()
            elapsedSeconds = 0
            elapsedTimer.start()
        } else {
            recordingStartTime = 0
            elapsedSeconds = 0
            elapsedTimer.stop()
        }
    }

    function refreshStatus() {
        if (!checkProcess.running)
            checkProcess.running = true
    }

    // Poll slightly less frequently - recording status doesn't need sub-second updates
    Timer {
        id: pollTimer
        interval: 1000
        running: Config.ready
        repeat: true
        onTriggered: root.refreshStatus()
    }

    // Elapsed time counter — ticks every second while recording
    Timer {
        id: elapsedTimer
        interval: 1000
        repeat: true
        onTriggered: {
            if (root.recordingStartTime > 0)
                root.elapsedSeconds = Math.floor((Date.now() - root.recordingStartTime) / 1000)
        }
    }

    Component.onCompleted: Qt.callLater(root.refreshStatus)

    Process {
        id: checkProcess
        command: ["/usr/bin/pgrep", "-x", "wf-recorder"]
        onExited: (exitCode, exitStatus) => {
            // pgrep returns 0 if process found, 1 if not found
            root.isRecording = (exitCode === 0)
        }
    }
}
