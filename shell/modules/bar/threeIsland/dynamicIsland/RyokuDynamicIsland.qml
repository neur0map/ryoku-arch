import qs
import qs.services
import qs.modules.common
import qs.modules.bar.threeIsland.dynamicIsland.pills
import qs.modules.bar.threeIsland.dynamicIsland.tools
import QtQuick

// Computes activeState from service singletons + Config flags. Loads the
// matching pill component. Phase 5: idle, recording, music, timer,
// screenshot toast, voice search, and tools mode are all wired.
Item {
    id: root
    implicitWidth: pillLoader.item ? pillLoader.item.implicitWidth : 0
    implicitHeight: Appearance.sizes.barHeight

    readonly property bool islandEnabled: Config.options?.bar?.dynamicIsland?.enabled ?? true

    function _anyTimerRunning() {
        return TimerService.pomodoroRunning
            || TimerService.countdownRunning
            || TimerService.stopwatchRunning;
    }

    readonly property string activeState: {
        const di = Config.options?.bar?.dynamicIsland;
        if (!di?.enabled) return "idle";
        if (GlobalStates.toolsModeOpen) return "tools";
        if ((di?.states?.voiceSearch ?? true)     && VoiceSearch.running)            return "voiceSearch";
        if ((di?.states?.recording ?? true)       && RecorderStatus.isRecording)     return "recording";
        if ((di?.states?.timer ?? true)           && _anyTimerRunning())             return "timer";
        if ((di?.states?.screenshotToast ?? true) && ScreenshotEvents.toastVisible)  return "screenshotToast";
        if ((di?.states?.music ?? true)           && MprisController.isPlaying)      return "music";
        return "idle";
    }

    // 250ms debounce so rapid state flapping (e.g. track transitions) does
    // not cause visible thrashing. Only morph after the new state has been
    // stable for the debounce interval.
    property string _debouncedState: "idle"

    Timer {
        id: debounceTimer
        interval: 250
        repeat: false
        onTriggered: root._debouncedState = root.activeState
    }

    onActiveStateChanged: debounceTimer.restart()

    function _componentFor(state) {
        switch (state) {
            case "tools":           return toolsComponent;
            case "voiceSearch":     return voiceSearchComponent;
            case "recording":       return recordingComponent;
            case "timer":           return timerComponent;
            case "screenshotToast": return screenshotToastComponent;
            case "music":           return musicComponent;
            case "idle":
            default:                return idleComponent;
        }
    }

    Loader {
        id: pillLoader
        anchors.fill: parent
        active: root.islandEnabled
        sourceComponent: root._componentFor(root._debouncedState)
    }

    Component { id: idleComponent;            IdleStatePill {} }
    Component { id: recordingComponent;       RecordingStatePill {} }
    Component { id: musicComponent;           MusicStatePill {} }
    Component { id: timerComponent;           TimerStatePill {} }
    Component { id: screenshotToastComponent; ScreenshotToastPill {} }
    Component { id: voiceSearchComponent;     VoiceSearchPill {} }
    Component { id: toolsComponent;           RyokuToolsMode {} }

    // toolsMode IpcHandler lives in services/ToolsModeService.qml so it
    // registers exactly once across all bar instances and stays alive even
    // before the tools pill is mounted. shell.qml force-instantiates that
    // singleton at startup.
}
