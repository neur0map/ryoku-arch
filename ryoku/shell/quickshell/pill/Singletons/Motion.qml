pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // reduceMotion (or the lowPowerMode master) collapses every animation to an
    // instant cut: durations go to 0, so Behaviors and transitions stop forcing
    // per-frame repaints -- the single biggest shell-animation win on a weak GPU.
    // Read straight from performance.json (the same file Performance and Ryoku
    // Settings use) so Motion stays a self-contained duration source.
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
    readonly property int morph:      reduce ? 0 : 420
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

    // bar module feedback: hover fills lift fast (the noctalia 100ms feel);
    // the workspace indicator's trailing edge settles at trail while its
    // leading edge moves at fast, so a switch stretches then contracts.
    readonly property int hover: reduce ? 0 : 100
    readonly property int trail: reduce ? 0 : 340

    // the caelestia curve family (Material 3 expressive), carried over with
    // its durations so the bar and its popouts move like the reference:
    //   emphasized      = the slide for indicators and reveals (400ms)
    //   spatialDefault  = spring with overshoot for popout travel (500ms)
    //   effectsDefault  = plain fades (200ms), effectsSlow for big reveals
    readonly property var emphasizedCurve: [0.05, 0, 0.133, 0.06, 0.167, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
    readonly property int emphasized: reduce ? 0 : 400
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property int spatial: reduce ? 0 : 500
    readonly property var effectsCurve: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property int effects: reduce ? 0 : 200
    readonly property var effectsSlowCurve: [0.34, 0.88, 0.34, 1, 1, 1]
    readonly property int effectsSlow: reduce ? 0 : 300
}
