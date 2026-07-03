pragma Singleton
import QtQuick
import Quickshell

// Overview motion budget, matched to the shell's tokens so the open/close and
// the window glides read like the rest of the desktop (docs/ui-ux.md: keep
// durations and easing consistent, OutExpo/OutCubic, no bespoke curves).
Singleton {
    readonly property int fast:     140
    readonly property int standard: 300
    readonly property int window:   240
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeExpo:     Easing.OutExpo
    // window show/close spends its budget on a low-bounce spring, like the
    // launcher, so the reveal is the felt moment.
    readonly property real windowSpring:  3.0
    readonly property real windowDamping: 0.85
    // tile drag snap-back and the active-cell ring track quickly.
    readonly property int highlight: 90
}
