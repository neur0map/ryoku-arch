pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// A single-select segmented control with a sliding indicator, in the pill's
// dossier idiom. `model` is a list of { key, label }; emits `selected(key)`.
Item {
    id: seg

    property var model: []
    property string current: ""
    property real s: 1
    signal selected(string key)

    readonly property real segW: 68 * s
    readonly property int count: model.length

    implicitWidth: count * segW + 8 * s
    implicitHeight: 26 * s

    function indexOfKey(k) {
        for (var i = 0; i < seg.model.length; i++)
            if (seg.model[i].key === k)
                return i;
        return 0;
    }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Theme.tileBg
        border.width: 1
        border.color: Theme.border
    }

    // Sliding selection indicator.
    Rectangle {
        y: 4 * seg.s
        height: parent.height - 8 * seg.s
        width: seg.segW
        x: 4 * seg.s + seg.indexOfKey(seg.current) * seg.segW
        radius: height / 2
        color: Theme.frameBg
        border.width: 1
        border.color: Theme.frameBorder
        Behavior on x { NumberAnimation { duration: Motion.standard; easing.type: Motion.easeStandard } }
    }

    Row {
        anchors.fill: parent
        anchors.margins: 4 * seg.s

        Repeater {
            model: seg.model

            delegate: Item {
                id: segDel
                required property var modelData
                width: seg.segW
                height: parent.height

                Text {
                    anchors.centerIn: parent
                    text: segDel.modelData.label
                    color: seg.current === segDel.modelData.key ? Theme.bright
                        : (h.hovered ? Theme.cream : Theme.dim)
                    font.family: Theme.font
                    font.pixelSize: 10 * seg.s
                    font.weight: seg.current === segDel.modelData.key ? Font.DemiBold : Font.Medium
                    font.letterSpacing: 1.2 * seg.s
                    font.capitalization: Font.AllUppercase
                    Behavior on color { ColorAnimation { duration: Motion.fast } }
                }

                HoverHandler { id: h; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: seg.selected(segDel.modelData.key) }
            }
        }
    }
}
