pragma ComponentBehavior: Bound

import QtQuick
import "../.."
import shell.services

// Music widget: a spectrum strip on the rail, fed by the shared AudioBars cava
// feed. On a vertical rail (left/right) the cava lines run horizontally and
// stack into a tall strip; on a horizontal rail they stand as a wide sweep.
// Self-hides until a real player reports a track (the shared Media pick already
// drops the live-wallpaper player); bars dance while playing and fall to dim
// rest slivers on pause. A lead gap sets the strip off from the dock above it.
// Left click opens the music card (the "music" surface). Claims the cava feed
// only while shown, so a playerless desktop never runs the analyser.
Item {
    id: root

    required property string edge
    required property real scale
    signal menuRequested(string id, rect ownerRect)

    readonly property bool vertical: root.edge === "left" || root.edge === "right"
    readonly property bool selfShown: Media.present
    // breathing room from the neighbour above (the dock) on a vertical rail.
    readonly property real lead: root.vertical ? 16 * root.scale : 0

    visible: selfShown
    implicitWidth: selfShown ? btn.implicitWidth : 0
    implicitHeight: selfShown ? (root.vertical ? btn.implicitHeight + root.lead : btn.implicitHeight) : 0

    onSelfShownChanged: AudioBars.setActive(root, root.selfShown)
    Component.onCompleted: AudioBars.setActive(root, root.selfShown)
    Component.onDestruction: AudioBars.setActive(root, false)

    RailButton {
        id: btn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: root.vertical ? parent.bottom : undefined
        anchors.verticalCenter: root.vertical ? undefined : parent.verticalCenter
        edge: root.edge
        scale: root.scale
        onClicked: root.menuRequested("music", Qt.rect(btn.x, btn.y, btn.width, btn.height))

        MusicBars {
            orient: root.vertical ? "horizontal" : "vertical"
            bands: root.vertical ? 13 : 7
            s: root.scale * 1.2
            width: root.vertical ? 28 * root.scale : implicitWidth
            height: root.vertical ? implicitHeight : 20 * root.scale
            running: Media.playing
            opacity: Media.playing ? 1 : 0.55
            Behavior on opacity { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
        }
    }
}
