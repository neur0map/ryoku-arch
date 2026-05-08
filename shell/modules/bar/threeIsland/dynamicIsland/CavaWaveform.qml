import qs.services
import qs.modules.common
import QtQuick

// Dense waveform visualizer adapted from Brain_Shell's PlayerCard.qml
// pattern: 32 bars, each a thin rounded Rectangle anchored to the bottom,
// height proportional to that band's amplitude (0-100 from cava). Color
// opacity ramps with amplitude (faint at 0, vivid at peak) so the row
// feels alive even in a small pill. 50ms OutCubic on height tween for
// snappy reaction without flicker.
Item {
    id: root

    property real maxBarHeight: 18
    property real minBarHeight: 2
    property real barWidth: 2
    property real spacing: 1
    property color barColor: "#7ac"
    // Multiplies height. When music is paused, we drop this to 0 so the
    // waveform flatlines instead of jiggling on residual noise.
    property bool active: true

    implicitWidth: (root.barWidth + root.spacing) * Cava.barCount - root.spacing
    implicitHeight: root.maxBarHeight

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: Cava.bars
            delegate: Item {
                required property int modelData
                required property int index
                width: root.barWidth
                height: root.maxBarHeight

                readonly property real _amp: root.active ? (modelData / 100.0) : 0

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(root.minBarHeight, _amp * root.maxBarHeight)
                    radius: width / 2
                    color: Qt.rgba(
                        root.barColor.r,
                        root.barColor.g,
                        root.barColor.b,
                        0.28 + _amp * 0.72)

                    Behavior on height {
                        enabled: Appearance.animationsEnabled
                        NumberAnimation { duration: 50; easing.type: Easing.OutCubic }
                    }
                }
            }
        }
    }
}
