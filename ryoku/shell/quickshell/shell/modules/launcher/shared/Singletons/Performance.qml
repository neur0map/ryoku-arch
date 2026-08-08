pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Performance toggles shared through ~/.config/ryoku/performance.json (the
// Performance section in Ryoku Settings writes it). The launcher reads the
// derived blur switch to drop its now-playing album-art blur on a weak GPU.
// lowPowerMode implies disableBlur.
Singleton {
    id: root

    readonly property bool lowPower: adapter.lowPowerMode
    readonly property bool blurDisabled: lowPower || adapter.disableBlur

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool lowPowerMode: false
            property bool disableBlur: false
        }
    }
}
