import QtQuick

// The now-playing pulse: a few bars that bounce while sound is moving, the small
// living sign a track is actually playing. Each bar animates its own height from
// the bottom, so no sibling relayout runs; when `live` drops the bars fall to a
// flat rest and the animation stops, so a paused or hidden sheet costs nothing.
Item {
    id: eq

    property real s: 1
    property color color: "white"
    property bool live: false
    property int bars: 4

    readonly property real barW: 3 * eq.s
    readonly property real gap: 2.5 * eq.s
    readonly property real maxH: 13 * eq.s
    readonly property real rest: 0.28

    implicitWidth: eq.bars * eq.barW + (eq.bars - 1) * eq.gap
    implicitHeight: eq.maxH

    Row {
        anchors.centerIn: parent
        spacing: eq.gap

        Repeater {
            model: eq.bars

            delegate: Item {
                id: bar
                required property int index
                width: eq.barW
                height: eq.maxH

                property real level: eq.rest

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    radius: width / 2
                    color: eq.color
                    height: (eq.live ? bar.level : eq.rest) * eq.maxH
                }

                SequentialAnimation on level {
                    running: eq.live && eq.visible
                    loops: Animation.Infinite
                    PauseAnimation { duration: bar.index * 85 }
                    NumberAnimation { to: 1.0;  duration: 260; easing.type: Easing.OutSine }
                    NumberAnimation { to: 0.35; duration: 300; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.82; duration: 240; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.22; duration: 320; easing.type: Easing.InOutSine }
                }
            }
        }
    }
}
