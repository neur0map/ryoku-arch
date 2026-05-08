import qs
import qs.services
import qs.modules.common
import qs.modules.bar.threeIsland.dynamicIsland.pills
import qs.modules.bar.threeIsland.dynamicIsland.tools
import QtQuick

// Center-notch content. Two stacked layers live inside the SAME notch so
// the user never sees one pill disappear before another appears, they just
// feel the center MORPH between idle/recording/music/etc and the tools row.
//
//   Layer A (state pill loader): idle / recording / music / ...
//   Layer B (tools row loader):  the Mod+S quicktools.
//
// _toolsProgress drives BOTH layers' opacity (cross-fade) AND the
// orchestrator's implicitWidth (so the notch grows/shrinks in lockstep
// with the fade rather than snapping to a fixed 520px). The notch shape
// itself is drawn by RyokuTopFrame and uses the existing centerNotchWidth
// OutBack Behavior in RyokuThreeIslandContent.
Item {
    id: root
    implicitHeight: Appearance.sizes.barHeight

    readonly property bool islandEnabled: Config.options?.bar?.dynamicIsland?.enabled ?? true

    function _anyTimerRunning() {
        return TimerService.pomodoroRunning
            || TimerService.countdownRunning
            || TimerService.stopwatchRunning;
    }

    // Non-tools active state. Tools is handled out-of-band by Layer B.
    readonly property string activeState: {
        const di = Config.options?.bar?.dynamicIsland;
        if (!di?.enabled) return "idle";
        if ((di?.states?.voiceSearch ?? true)     && VoiceSearch.running)            return "voiceSearch";
        if ((di?.states?.recording ?? true)       && RecorderStatus.isRecording)     return "recording";
        if ((di?.states?.timer ?? true)           && _anyTimerRunning())             return "timer";
        if ((di?.states?.screenshotToast ?? true) && ScreenshotEvents.toastVisible)  return "screenshotToast";
        if ((di?.states?.music ?? true)           && MprisController.isPlaying)      return "music";
        return "idle";
    }

    // 250ms debounce so rapid signal flapping (track transitions, etc.)
    // does not cause visible thrashing. Tools mode bypasses this entirely.
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
            case "voiceSearch":     return voiceSearchComponent;
            case "recording":       return recordingComponent;
            case "timer":           return timerComponent;
            case "screenshotToast": return screenshotToastComponent;
            case "music":           return musicComponent;
            case "idle":
            default:                return idleComponent;
        }
    }

    // Two separately-paced progresses so the notch finishes growing BEFORE
    // (or at the same time as) the icon content lands. Otherwise icons
    // appear fully visible inside a still-growing notch.
    //
    //   _widthProgress  : drives notch width interpolation. Matches the
    //                     parent's centerNotchWidth Behavior (320ms OutBack
    //                     1.6) so the orchestrator's implicitWidth and the
    //                     visible notch animate in sync.
    //   _contentProgress: drives tools-row opacity + vertical slide.
    //                     Delayed 120ms when opening so the notch has a head
    //                     start, then bounces in over 200ms (OutBack 1.4).
    //                     On close, snaps to 0 immediately so icons fade
    //                     out FIRST, then the empty notch retracts.
    property real _widthProgress: GlobalStates.toolsModeOpen ? 1.0 : 0.0
    Behavior on _widthProgress {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: 320; easing.type: Easing.OutBack; easing.overshoot: 1.6 }
    }

    property real _contentProgress: 0.0
    Behavior on _contentProgress {
        enabled: Appearance.animationsEnabled
        NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
    }
    Timer {
        id: _contentDelayTimer
        interval: 120
        onTriggered: root._contentProgress = 1.0
    }
    Connections {
        target: GlobalStates
        function onToolsModeOpenChanged() {
            if (GlobalStates.toolsModeOpen) {
                _contentDelayTimer.restart();
            } else {
                _contentDelayTimer.stop();
                root._contentProgress = 0.0;
            }
        }
    }

    // Width interpolates from the state pill's natural width to the tools
    // row's natural width, weighted by _widthProgress. The bar's
    // centerNotchWidth Behavior smooths this further with OutBack overshoot.
    readonly property real _stateWidth: pillLoader.item ? pillLoader.item.implicitWidth : 0
    readonly property real _toolsWidth: toolsLoader.item ? toolsLoader.item.implicitWidth : _stateWidth
    implicitWidth: _stateWidth + (_toolsWidth - _stateWidth) * _widthProgress

    // Layer A: regular state pills (idle, recording, music, ...).
    // Fades out with the icon content (matches the close: icons go first,
    // notch retracts after).
    Loader {
        id: pillLoader
        anchors.fill: parent
        active: root.islandEnabled
        sourceComponent: root._componentFor(root._debouncedState)
        opacity: 1.0 - root._contentProgress
        visible: opacity > 0.01
    }

    // Layer B: tools row. Slides down from above (-14px → 0) and fades in
    // ON the contentProgress curve, so it lands right as the notch finishes
    // growing.
    Loader {
        id: toolsLoader
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: (1.0 - root._contentProgress) * -14
        active: GlobalStates.toolsModeOpen || root._contentProgress > 0.01 || root._widthProgress > 0.01
        sourceComponent: toolsComponent
        opacity: Math.max(0, Math.min(1, root._contentProgress))
        visible: opacity > 0.01
    }


    Component { id: idleComponent;            IdleStatePill {} }
    Component { id: recordingComponent;       RecordingStatePill {} }
    Component { id: musicComponent;           MusicStatePill {} }
    Component { id: timerComponent;           TimerStatePill {} }
    Component { id: screenshotToastComponent; ScreenshotToastPill {} }
    Component { id: voiceSearchComponent;     VoiceSearchPill {} }
    Component { id: toolsComponent;           RyokuToolsMode {} }

    // toolsMode IpcHandler lives in services/ToolsModeService.qml so it
    // registers once globally and stays alive even before the tools row
    // mounts. shell.qml force-instantiates that singleton at startup.
}
