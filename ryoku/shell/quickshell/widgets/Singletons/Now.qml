pragma Singleton
import QtQuick
import Quickshell

// the shared wall clock for desktop widgets. one 1s tick drives every face
// and the analog second hand, so they stay in lockstep and the desktop isn't
// running two timers for the same time. minute-only designs ignore seconds.
Singleton {
    id: root

    property var date: new Date()

    // YYYY-MM-DD of today. changes once per day, so faces that only mark the
    // current day (month/heat/minimal) derive their "today" off this and don't
    // re-evaluate their whole grid on every 1s tick. `date` stays for anything
    // that shows the time.
    readonly property string dayKey: Qt.formatDate(root.date, "yyyy-MM-dd")

    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.date = new Date()
    }
}
