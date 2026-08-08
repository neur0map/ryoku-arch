pragma ComponentBehavior: Bound
import QtQuick
import shell.services
import "../Singletons"

// The no-lyrics backdrop: a live cava spectrum in the sleeve's colour, so a
// track with no words still moves instead of showing a dead "no lyrics" panel.
// The analyser (AudioBars, the shared 40-band cava feed) is owner-refcounted and
// claimed only while this is visible and a track plays, so a paused sheet, a
// track that has lyrics, or a hidden widget all cost nothing. Bars grow from the
// mid-line both ways, settling to a row of slivers when the feed goes quiet.
Item {
    id: viz

    property real s: 1
    property color accent: Theme.accent
    property bool live: false

    readonly property bool wanted: viz.live && viz.visible
    onWantedChanged: AudioBars.setActive(viz, viz.wanted)
    Component.onCompleted: AudioBars.setActive(viz, viz.wanted)
    Component.onDestruction: AudioBars.setActive(viz, false)

    readonly property int count: AudioBars.bars
    readonly property real pitch: viz.width / Math.max(1, viz.count)
    readonly property real barW: Math.max(2 * viz.s, viz.pitch * 0.55)
    readonly property real maxH: viz.height * 0.8

    Repeater {
        model: viz.count

        delegate: Item {
            id: slot
            required property int index
            x: slot.index * viz.pitch
            width: viz.pitch
            height: viz.height

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                width: viz.barW
                radius: width / 2
                color: viz.accent
                opacity: 0.85
                height: Math.max(viz.barW, (AudioBars.active
                    ? (AudioBars.levels[slot.index] || 0) : 0) * viz.maxH)
                Behavior on height { NumberAnimation { duration: 90; easing.type: Easing.OutSine } }
            }
        }
    }
}
