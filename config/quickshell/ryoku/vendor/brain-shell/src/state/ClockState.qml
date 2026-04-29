pragma Singleton
import QtQuick

// ClockState — exposes active clock module state for the dynamic island.
// Written by ClockCard, read by CenterNotch / dynamic island.

QtObject {
    // Timer
    property bool   timerRunning: false
    property bool   timerStarted:   false
    property int    timerLeft:    0
    property int    timerTotal:   0
    property string timerDisplay: "00:00"

    // Stopwatch
    property bool   swRunning: false
    property bool   swStarted:   false
    property string swDisplay: "00:00"
    
    signal requestStopwatchReset()
    signal requestTimerReset()

    // Alarms — list of { id, hour, minute, label, enabled }
    property var alarms: []

    // Nearest upcoming enabled alarm: { hour, minute, label, minsUntil } or null
    property var nextAlarm: null

    // True when something is actively running
    readonly property bool hasActiveEvent:
        timerRunning || swRunning || nextAlarm !== null
}
