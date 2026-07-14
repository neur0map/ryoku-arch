pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Opt-in performance toggles, shared through ~/.config/ryoku/performance.json
// (the Performance section in Ryoku Settings writes it). Off by default. The
// global low-power switches let a weak GPU run the shell without lag; the
// lowPowerMode master implies every reduce/disable below, so consumers bind to
// the derived booleans (pillFrozen / motionReduced / blurDisabled /
// shadowsDisabled), never the raw opt-ins.
Singleton {
    id: root

    // master: the one potato switch. implies every reduce/disable below.
    readonly property bool lowPower: adapter.lowPowerMode

    // derived switches consumers read (master OR the matching individual opt-in).
    readonly property bool pillFrozen:      lowPower || adapter.freezePillWhenIdle
    readonly property bool motionReduced:   lowPower || adapter.reduceMotion
    readonly property bool blurDisabled:    lowPower || adapter.disableBlur
    readonly property bool shadowsDisabled: lowPower || adapter.disableShadows

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()

        JsonAdapter {
            id: adapter
            property bool freezePillWhenIdle: false
            property bool lowPowerMode: false
            property bool reduceMotion: false
            property bool disableBlur: false
            property bool disableShadows: false
        }
    }
}
