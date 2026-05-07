import qs
import qs.services
import qs.modules.common
import qs.modules.bar.threeIsland.dynamicIsland.pills
import QtQuick

// Computes activeState from service singletons + Config flags. Loads the
// matching pill component. Phase 2: idle + recording wired. Later phases
// add the others.
Item {
    id: root
    implicitWidth: pillLoader.item ? pillLoader.item.implicitWidth : 0
    implicitHeight: Appearance.sizes.barHeight

    readonly property bool islandEnabled: Config.options?.bar?.dynamicIsland?.enabled ?? true

    readonly property string activeState: {
        const di = Config.options?.bar?.dynamicIsland;
        if (!di?.enabled) return "idle";
        if ((di?.states?.recording ?? true) && RecorderStatus.isRecording) return "recording";
        return "idle";
    }

    function _componentFor(state) {
        switch (state) {
            case "recording": return recordingComponent;
            case "idle":
            default:          return idleComponent;
        }
    }

    Loader {
        id: pillLoader
        anchors.fill: parent
        active: root.islandEnabled
        sourceComponent: root._componentFor(root.activeState)
    }

    Component { id: idleComponent;      IdleStatePill {} }
    Component { id: recordingComponent; RecordingStatePill {} }
}
