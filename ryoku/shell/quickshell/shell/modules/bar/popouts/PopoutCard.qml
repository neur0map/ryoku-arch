pragma ComponentBehavior: Bound

import QtQuick
import shell.services

// The reusable frame-edge card skin, factored out of the music card: the framed
// instrument tile (flat surface, hairline border) plus the click-swallow that
// stops a body click from falling through to the dismiss backdrop. Drop it in as
// an `anchors.fill: parent` background of a popout whose root owns the sizing;
// the grow/melt from the frame edge is owned by the shared Popout via
// FrameSurface. Every card that uses it reads and dismisses identically.
Item {
    id: root

    Rectangle {
        anchors.fill: parent
        radius: Theme.radiusWindow
        color: Theme.surface
        border.width: Theme.borderWidth
        border.color: Theme.outline
    }
    MouseArea { anchors.fill: parent }
}
