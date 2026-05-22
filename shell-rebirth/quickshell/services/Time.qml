pragma Singleton
import Quickshell
import QtQuick

Singleton {
    id: root

    property alias date: clock.date
    readonly property SystemClock clock: clock

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // Helper function if you still want formatting ability:
    function format(fmt) {
        return Qt.formatDateTime(clock.date, fmt)
    }
}