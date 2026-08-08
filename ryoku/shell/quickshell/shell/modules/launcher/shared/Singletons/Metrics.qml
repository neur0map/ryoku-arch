pragma Singleton
import QtQuick
import Quickshell

// Shared type and spacing tokens. Shutter geometry belongs to results.js so its
// QML and unit-test consumers cannot drift apart.
Singleton {
    readonly property real gapTab:    16

    readonly property int  fontTitle:    13
    readonly property int  fontSubtitle: 10
    readonly property int  fontEyebrow:  9

    // results past this scroll; keeps the keystroke->paint budget bounded.
    readonly property int  maxResults:   40
}
