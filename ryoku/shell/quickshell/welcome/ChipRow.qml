pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// A wrapping row of single-select chips. Unlike a fixed segmented control it holds
// two choices or six without crowding, and wraps to a second line on a narrow
// column. `model` is a list of { key, label }; the selected chip carries the ember
// accent.
Flow {
    id: chips

    property var model: []
    property string current: ""
    signal selected(string key)

    spacing: 8

    Repeater {
        model: chips.model

        delegate: Rectangle {
            id: chip
            required property var modelData
            readonly property bool on: chips.current === chip.modelData.key

            implicitWidth: t.implicitWidth + 26
            height: 32
            radius: Theme.radius
            color: chip.on ? Theme.keyTop : (h.hovered ? Theme.surfaceLo : "transparent")
            border.width: 1
            border.color: chip.on ? Theme.ember : (h.hovered ? Theme.cream : Theme.line)
            Behavior on color { ColorAnimation { duration: Theme.quick } }
            Behavior on border.color { ColorAnimation { duration: Theme.quick } }

            Text {
                id: t
                anchors.centerIn: parent
                text: chip.modelData.label
                color: chip.on ? Theme.bright : (h.hovered ? Theme.cream : Theme.dim)
                font.family: Theme.font
                font.pixelSize: 12
                font.weight: chip.on ? Font.DemiBold : Font.Medium
                Behavior on color { ColorAnimation { duration: Theme.quick } }
            }

            HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: chips.selected(chip.modelData.key) }
        }
    }
}
