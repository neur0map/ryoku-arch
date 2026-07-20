pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// RyoLayer motion budget, matched to the shell's tokens (docs/ui-ux.md): the
// board reveals like the overview (fade + small scale settle), slots snap like
// controls. reduceMotion / lowPowerMode collapse everything to a cut, and the
// same file's blur switch gates the backdrop frost (shell.qml reads it here so
// this surface keeps one performance reader).
Singleton {
    id: root

    readonly property bool reduce: perf.lowPowerMode || perf.reduceMotion
    readonly property bool blurDisabled: perf.lowPowerMode || perf.disableBlur

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: perf
            property bool lowPowerMode: false
            property bool reduceMotion: false
            property bool disableBlur: false
        }
    }

    readonly property int fast:     reduce ? 0 : 140
    readonly property int window:   reduce ? 0 : 240
    readonly property int settle:   reduce ? 0 : 170
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeExpo:     Easing.OutExpo
}
