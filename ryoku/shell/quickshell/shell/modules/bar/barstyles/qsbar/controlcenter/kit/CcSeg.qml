import QtQuick
import "../../modules"

// A segmented choice. Neutral hover; accent only on the selected option.
// `options` is a list of strings, or of {key,label} objects.
Row {
    id: seg
    property var root
    property var options: []
    property string current: ""
    signal chose(string key)

    spacing: 4

    Repeater {
        model: seg.options
        delegate: Rectangle {
            id: opt
            required property var modelData
            readonly property string key: (typeof modelData === "string") ? modelData : modelData.key
            readonly property string lbl: (typeof modelData === "string") ? modelData : (modelData.label || modelData.key)
            readonly property bool on: seg.current === key
            readonly property color hf: Qt.rgba(seg.root.ink.r, seg.root.ink.g, seg.root.ink.b, 0.06)
            readonly property color hb: Qt.rgba(seg.root.ink.r, seg.root.ink.g, seg.root.ink.b, 0.28)

            width: Math.max(46, lblText.implicitWidth + 20)
            height: 28
            radius: seg.root.tileRadius
            color: on ? Qt.rgba(seg.root.seal.r, seg.root.seal.g, seg.root.seal.b, 0.14)
                      : (ma.containsMouse ? opt.hf : seg.root.fillIdle)
            border.width: 1
            border.color: on ? Qt.rgba(seg.root.seal.r, seg.root.seal.g, seg.root.seal.b, 0.52)
                             : (ma.containsMouse ? opt.hb : seg.root.sep)
            Behavior on color { ColorAnimation { duration: 120 } }

            UiText {
                id: lblText
                anchors.centerIn: parent
                text: opt.lbl
                color: opt.on ? seg.root.seal : seg.root.ink
                font.family: seg.root.mono
                font.pixelSize: 11
                font.weight: opt.on ? Font.DemiBold : Font.Normal
            }
            MouseArea {
                id: ma
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: seg.chose(opt.key)
            }
        }
    }
}
