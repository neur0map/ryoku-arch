pragma Singleton
import QtQuick
import Quickshell

// the shared wall clock for desktop widgets. one 1s tick drives every face
// and the analog second hand, so they stay in lockstep and the desktop isn't
// running two timers for the same time. minute-only designs ignore seconds.
Singleton {
    id: root

    property var date: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.date = new Date()
    }
}
