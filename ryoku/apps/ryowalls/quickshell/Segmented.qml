import QtQuick
import "Singletons"

// Single-select segmented control with a sliding selection pill, matching the
// hub's moving-indicator look. `model` = list of { key, label }.
Item {
    id: seg

    property var model: []
    property string current: ""
    property real segW: 92
    signal selected(string key)

    readonly property int count: model.length

    implicitWidth: count * segW + 8
    implicitHeight: 34

    function indexOfKey(k) {
        for (var i = 0; i < model.length; i++)
            if (model[i].key === k)
                return i;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.surfaceLo
        border.width: 1
        border.color: Theme.line
    }

    Rectangle {
        y: 4
        height: parent.height - 8
        width: seg.segW
        x: 4 + seg.indexOfKey(seg.current) * seg.segW
        radius: height / 2
        color: Theme.keyTop
        border.width: 1
        border.color: Theme.line
        Behavior on x { NumberAnimation { duration: Theme.medium; easing.type: Theme.ease } }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 4

        Repeater {
            model: seg.model
            delegate: Item {
                required property var modelData
                width: seg.segW
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: parent.modelData.label
                    color: seg.current === parent.modelData.key ? Theme.bright
                        : (h.hovered ? Theme.cream : Theme.dim)
                    font.family: Theme.font
                    font.pixelSize: 12
                    font.weight: seg.current === parent.modelData.key ? Font.DemiBold : Font.Medium
                    Behavior on color { ColorAnimation { duration: Theme.quick } }
                }

                HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: seg.selected(parent.modelData.key) }
            }
        }
    }
}
