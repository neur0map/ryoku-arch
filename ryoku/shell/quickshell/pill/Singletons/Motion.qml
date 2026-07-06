pragma Singleton
import QtQuick
import Quickshell

Singleton {
    readonly property int fast:     140
    readonly property int standard: 300
    readonly property int morph:    420
    readonly property int shapeshift: 820
    readonly property int glide:    260
    readonly property int heat:     1100
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeMorph:    Easing.BezierSpline

    // liquid morph curve, cubic-bezier(0.16, 1, 0.3, 1). front-loaded like an
    // exponential chase but with a long visible settle tail. pair with easeMorph
    // (BezierSpline).
    readonly property var morphCurve: [0.16, 1, 0.3, 1, 1, 1]
    readonly property real rSmall: 7
    readonly property real rTile:  13

    // looping scan/pairing breath pulse.
    readonly property int pulse: 420

    // bar module feedback: hover fills lift fast (the noctalia 100ms feel);
    // the workspace indicator's trailing edge settles at trail while its
    // leading edge moves at fast, so a switch stretches then contracts.
    readonly property int hover: 100
    readonly property int trail: 340

    // the caelestia curve family (Material 3 expressive), carried over with
    // its durations so the bar and its popouts move like the reference:
    //   emphasized      = the slide for indicators and reveals (400ms)
    //   spatialDefault  = spring with overshoot for popout travel (500ms)
    //   effectsDefault  = plain fades (200ms), effectsSlow for big reveals
    readonly property var emphasizedCurve: [0.05, 0, 0.133, 0.06, 0.167, 0.4, 0.208, 0.82, 0.25, 1, 1, 1]
    readonly property int emphasized: 400
    readonly property var spatialCurve: [0.38, 1.21, 0.22, 1, 1, 1]
    readonly property int spatial: 500
    readonly property var effectsCurve: [0.34, 0.8, 0.34, 1, 1, 1]
    readonly property int effects: 200
    readonly property var effectsSlowCurve: [0.34, 0.88, 0.34, 1, 1, 1]
    readonly property int effectsSlow: 300
}
