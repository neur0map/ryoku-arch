pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Opt-in performance toggles, shared through ~/.config/ryoku/performance.json
// (the Performance section in Ryoku Settings writes it). Off by default, so the
// bead keeps its idle swirl and breath unless a user opts into freezing it.
Singleton {
    id: root

    property alias freezePillWhenIdle: adapter.freezePillWhenIdle

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool freezePillWhenIdle: false
        }
    }
}
