pragma Singleton

import Quickshell
import Quickshell.Io

// Read-only mirror of the main shell's game mode state. The main GameMode
// service (shell/services/GameMode.qml) writes the shared state file on every
// toggle; this watches it so dashboard surfaces (e.g. Config.animDuration)
// follow along. The legacy axctl enable/disable path is gone — the dashboard
// only consumes the state, it never drives it.
Singleton {
    id: root

    property bool toggled: false

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/ryoku/gamemode.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.toggled = !!JSON.parse(text()).enabled
            } catch (e) {
                root.toggled = false
            }
        }
        onLoadFailed: root.toggled = false
    }
}
