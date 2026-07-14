pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Performance toggles, shared through ~/.config/ryoku/performance.json (the
// Performance section in Ryoku Settings writes it). The visualiser freezes when
// silent by default -- its idle animation otherwise leaks on this Qt/NVIDIA
// stack. The lowPowerMode master implies the freeze and the bloom-off below, so
// consumers read the derived booleans, not the raw opt-ins.
Singleton {
    id: root

    readonly property bool lowPower: adapter.lowPowerMode
    readonly property bool visualizerFrozen: lowPower || adapter.freezeVisualizerWhenIdle
    readonly property bool blurDisabled:     lowPower || adapter.disableBlur

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool freezeVisualizerWhenIdle: true
            property bool lowPowerMode: false
            property bool disableBlur: false
        }
    }
}
