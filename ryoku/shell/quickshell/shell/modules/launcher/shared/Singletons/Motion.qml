pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // reduceMotion / lowPowerMode collapse every duration to an instant cut so a
    // weak GPU stops repainting through transitions. Read from performance.json,
    // the same file Ryoku Settings and the Performance singleton use.
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

    readonly property int fast:       reduce ? 0 : 140
    readonly property int standard:   reduce ? 0 : 300
    readonly property int shapeshift: reduce ? 0 : 820
    readonly property int glide:      reduce ? 0 : 260
    readonly property int heat:       reduce ? 0 : 1100
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline

    // liquid morph curve, cubic-bezier(0.16, 1, 0.3, 1). front-loaded like an
    // exponential chase but with a long visible settle tail. pair with easeMorph
    // (BezierSpline).
    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
    readonly property real rSmall: 7
    readonly property real rTile:  13

    // looping scan/pairing breath pulse.
    readonly property int pulse: reduce ? 0 : 420

    // Shutter motion explains a state change rather than decorating every
    // keystroke. Task 7 consumes open/close for the layer-surface lifecycle.
    readonly property int open:      reduce ? 0 : 210
    readonly property int close:     reduce ? 0 : 160
    readonly property int shutter:   reduce ? 0 : 360
    readonly property int drawer:    reduce ? 0 : 280
    readonly property int selection: reduce ? 0 : 90
    readonly property int shelf:     reduce ? 0 : 180

}
