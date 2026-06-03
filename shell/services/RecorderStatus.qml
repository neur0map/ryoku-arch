pragma Singleton

import Quickshell
import qs.services

// Ryoku RecorderStatus: maps onto Ryoku's Recorder service. Also exposes start/stop
// so the Recorder widget can drive Ryoku's recorder without colliding with its own
// `Recorder` type name.
Singleton {
    readonly property bool isRecording: Recorder.running
    readonly property int elapsedSeconds: Math.floor(Recorder.elapsed)

    function start(args) {
        Recorder.start(args ?? []);
    }

    function stop() {
        Recorder.stop();
    }
}
