import QtQuick
import "Singletons"

// 5-8 exclusive named options. wraps; the selected chip inverts.
Flow {
    id: chips
    property var options: []
    property string current: ""
    signal chose(string key)

    spacing: 5

    Repeater {
        model: chips.options
        Rectangle {
            required property string modelData
            readonly property bool on: chips.current === modelData
            width: cl.width + 18
            height: 24
            radius: Tokens.radius
            color: on ? Tokens.bone : (ch.hovered ? Tokens.tint10 : "transparent")
            border.width: Tokens.border
            border.color: ch.hovered && !on ? Tokens.lineStrong : Tokens.line
            Behavior on color { ColorAnimation { duration: Tokens.snap } }
            Text {
                id: cl
                anchors.centerIn: parent
                text: I18n.tr(parent.modelData)
                color: parent.on ? Tokens.inkOnBone : Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: 10
                font.weight: Font.Medium
            }
            HoverHandler { id: ch; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: chips.chose(parent.modelData) }
        }
    }
}
