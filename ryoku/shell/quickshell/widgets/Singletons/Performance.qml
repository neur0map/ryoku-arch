pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Performance toggles shared through ~/.config/ryoku/performance.json (the
// Performance section in Ryoku Settings writes it). The desktop-widget layer
// reads the derived shadow switch to drop its per-tile drop shadows (a GPU blur
// pass each) on a weak GPU. lowPowerMode implies disableShadows.
Singleton {
    id: root

    readonly property bool lowPower: adapter.lowPowerMode
    readonly property bool shadowsDisabled: lowPower || adapter.disableShadows

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool lowPowerMode: false
            property bool disableShadows: false
        }
    }
}
