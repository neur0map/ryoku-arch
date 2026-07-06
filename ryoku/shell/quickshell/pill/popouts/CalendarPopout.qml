pragma ComponentBehavior: Bound

import QtQuick
import ".."

// calendar popout content: the month calendar opened from the clock. holds the
// Calendar surface (a PillSurface) pinned statically open so the Popout's blob
// does the reveal instead of the pill morph. a bare, transparent Item -- the
// Popout blob behind it IS the surface; this panel only reports its implicit
// size so the popout melts open to fit. pointer-driven, no keyboard focus.
Item {
    id: root

    property real s: 1
    property bool open: false

    implicitWidth: 318 * root.s
    implicitHeight: cal.implicitHeight + 32 * root.s

    Calendar {
        id: cal
        anchors.fill: parent
        s: root.s
        open: true
        shown: true
        openProgress: 1
        openW: root.implicitWidth
        openH: root.implicitHeight
    }
}
