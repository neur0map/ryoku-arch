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

    // launcher motion budget: keystroke->results never animates (0); the action
    // panel and view pushes get a short ease; the window show/hide spends the
    // budget on a low-bounce spring so the open/close is the felt moment.
    readonly property int panel:    140
    readonly property int viewPush: 180
    readonly property int window:   240
    readonly property real windowSpring:  3.0
    readonly property real windowDamping: 0.85
    // selected-row highlight tracks the new row without blocking input.
    readonly property int highlight: 80
}
