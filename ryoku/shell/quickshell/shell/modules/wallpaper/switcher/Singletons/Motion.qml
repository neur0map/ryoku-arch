pragma Singleton
import QtQuick
import Quickshell

// Motion budget, matched to the shell tokens so the switcher's open/close and
// selection glides read like the rest of the desktop (docs/ui-ux.md: consistent
// durations, OutCubic/OutExpo, no bespoke curves).
Singleton {
    readonly property int fast:     140
    readonly property int standard: 300
    readonly property int window:   240
    readonly property int highlight: 90
    // filmstrip / carousel focus travel: a touch quicker than a full swap.
    readonly property int beltEase: 260
    readonly property int easeStandard: Easing.OutCubic
    readonly property int easeExpo:     Easing.OutExpo

    // thumbnail / card hover lift + border tint: CSS `ease` over 150ms, matching
    // the shell's menu thumbnails.
    readonly property int thumbHover: 150
    readonly property int easeType: Easing.Bezier
    readonly property var easeCurve: [0.25, 0.1, 0.25, 1, 1, 1]
}
