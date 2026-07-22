import QtQuick
import "Singletons"

// 2-4 exclusive named modes, labels short. five or more is never a seg --
// Spans.controlFor() enforces that; this only draws.
Row {
    id: seg
    property var options: []
    property string current: ""
    signal chose(string key)

    spacing: 0

    Repeater {
        model: seg.options
        Rectangle {
            required property string modelData
            readonly property bool on: seg.current === modelData
            width: Math.max(52, lab.width + 18)
            height: 24
            radius: Tokens.radius
            color: on ? Tokens.bone : (sh.hovered ? Tokens.tint10 : "transparent")
            border.width: Tokens.border
            border.color: sh.hovered && !on ? Tokens.lineStrong : Tokens.line
            Behavior on color { ColorAnimation { duration: Tokens.snap } }

            Text {
                id: lab
                anchors.centerIn: parent
                text: I18n.tr(parent.modelData)
                color: parent.on ? Tokens.inkOnBone : Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: 9
                font.weight: Font.Medium
                font.letterSpacing: 0.6
            }
            HoverHandler { id: sh; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: seg.chose(parent.modelData) }
        }
    }
}
