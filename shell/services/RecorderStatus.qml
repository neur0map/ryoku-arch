pragma Singleton

import Quickshell
import qs.services

// RYOKU compat shim for iNiR's `RecorderStatus`, mapping onto ryoku's Recorder
// service. Also exposes start/stop so the vendored Recorder widget can drive
// ryoku's recorder without colliding with its own `Recorder` type name.
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
