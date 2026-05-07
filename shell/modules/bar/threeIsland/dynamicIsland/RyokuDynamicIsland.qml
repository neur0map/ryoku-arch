import qs
import qs.services
import qs.modules.common
import qs.modules.bar.threeIsland.dynamicIsland.pills
import QtQuick

// Computes activeState from service singletons + Config flags. Loads the
// matching pill component. Phase 1: only "idle" is wired up; later phases
// add the others.
Item {
    id: root
    implicitWidth: pillLoader.item ? pillLoader.item.implicitWidth : 0
    implicitHeight: Appearance.sizes.barHeight

    readonly property bool islandEnabled: Config.options?.bar?.dynamicIsland?.enabled ?? true

    // Phase 1: only idle. Future phases extend this.
    readonly property string activeState: "idle"

    Loader {
        id: pillLoader
        anchors.fill: parent
        active: root.islandEnabled
        sourceComponent: root.activeState === "idle" ? idleComponent : null
    }

    Component { id: idleComponent; IdleStatePill {} }
}
