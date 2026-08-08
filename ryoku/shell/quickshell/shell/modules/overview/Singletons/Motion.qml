pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Overview motion budget, matched to the shell's tokens so the open/close and
// the window glides read like the rest of the desktop (docs/ui-ux.md: keep
// durations and easing consistent, OutExpo/OutCubic, no bespoke curves).
Singleton {
    id: root

    // reduceMotion / lowPowerMode collapse every duration to an instant cut so a
    // weak GPU stops repainting through the expo reveal. Read from
    // performance.json, the same file Ryoku Settings and Performance use.
    readonly property bool reduce: perf.lowPowerMode || perf.reduceMotion

    FileView {
        path: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/ryoku/performance.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        JsonAdapter {
            id: perf
            property bool lowPowerMode: false
            property bool reduceMotion: false
        }
    }

    readonly property int fast:     reduce ? 0 : 140
    readonly property int standard: reduce ? 0 : 300
    readonly property int window:   reduce ? 0 : 240
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeExpo:     Easing.OutExpo
    // window show/close spends its budget on a low-bounce spring, like the
    // launcher, so the reveal is the felt moment.
    readonly property real windowSpring:  reduce ? 12.0 : 3.0
    readonly property real windowDamping: reduce ? 1.0 : 0.85
    // tile drag snap-back and the active-cell ring track quickly.
    readonly property int highlight: reduce ? 0 : 90
}
