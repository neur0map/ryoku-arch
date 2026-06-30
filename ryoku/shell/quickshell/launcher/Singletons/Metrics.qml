pragma Singleton
import QtQuick
import Quickshell

// Layout tokens for the launcher, so spacing/sizing live in one place instead of
// scattered literals. Base pixels at 1080p; components multiply by the per-monitor
// scale where they read them, matching the pill's convention.
Singleton {
    readonly property real windowW:      560
    readonly property real searchHeight: 46
    readonly property real rowHeight:    40
    readonly property real iconSize:     22
    readonly property real tileSize:     92
    readonly property int  gridColumns:  6

    readonly property real padOuter:  16
    readonly property real padRow:    10
    readonly property real gapRow:    2
    readonly property real gapTab:    16
    // height of a result-list section header (type label + hairline). The list
    // height calc and the row delegate both read this so they never disagree.
    readonly property real sectionH: 18

    readonly property real radiusWindow: 16
    // rest card: one step inside the window radius (and the Hyprland window
    // rounding of 16) so nested corners read as concentric, not arbitrary.
    readonly property real radiusCard:   12
    readonly property real radiusRow:    9
    readonly property real radiusTag:    6
    readonly property real radiusGlyph:  9

    readonly property int  fontTitle:    13
    readonly property int  fontSubtitle: 10
    readonly property int  fontEyebrow:  9
    readonly property int  fontSearch:   14
    readonly property int  fontSection:  12

    // results past this scroll; keeps the keystroke->paint budget bounded.
    readonly property int  maxResults:   40
}
