import QtQuick
import "Singletons"

// A row of equal-width options; the selected one glows ember.
Row {
    id: seg
    property var options: []
    property int current: 0
    signal picked(int i)
    spacing: 6
    Repeater {
        model: seg.options
        Rectangle {
            id: chip
            required property int index
            required property var modelData
            width: (seg.width - (seg.options.length - 1) * 6) / Math.max(1, seg.options.length)
            height: 30
            radius: Theme.radiusSm
            readonly property bool sel: seg.current === chip.index
            color: chip.sel ? Theme.ember : (ma.containsMouse ? Theme.fieldHi : Theme.field)
            Text {
                anchors.centerIn: parent; text: chip.modelData
                color: chip.sel ? "#ffffff" : Theme.idle
                font.family: Theme.font; font.pixelSize: 12; font.weight: chip.sel ? Font.DemiBold : Font.Medium
            }
            MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(chip.index) }
        }
    }
}
