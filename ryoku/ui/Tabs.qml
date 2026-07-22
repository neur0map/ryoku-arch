import QtQuick
import "Singletons"

// The tab bar, once. Selection is typography, not a coloured bar: the active
// plate inverts to bone and its label takes the sheet's // lead, the reference
// poster's `001 // ABOUT` register. Plates size to their labels.
Row {
    id: tabs

    property var options: []        // list of labels
    property string current: ""
    signal chose(string label)

    spacing: 0

    Repeater {
        model: tabs.options
        Rectangle {
            id: plate
            required property string modelData
            readonly property bool on: tabs.current === modelData

            width: lab.implicitWidth + 30
            height: 34
            radius: Tokens.radius
            color: on ? Tokens.bone : (th.hovered ? Tokens.tint5 : "transparent")
            border.width: Tokens.border
            border.color: on ? Tokens.bone : Tokens.line
            Behavior on color { ColorAnimation { duration: Tokens.snap } }

            Row {
                id: lab
                anchors.centerIn: parent
                spacing: Tokens.s2
                Text {
                    visible: plate.on
                    text: "//"
                    color: Tokens.inkOnBoneDim
                    font.family: Tokens.mono
                    font.pixelSize: 10
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text {
                    // translate the display, emit the original value on tap so the
                    // tab key still matches for filtering/selection.
                    text: I18n.tr(plate.modelData).toUpperCase()
                    color: plate.on ? Tokens.inkOnBone : Tokens.inkDim
                    font.family: Tokens.ui
                    font.pixelSize: 11
                    font.weight: Font.Medium
                    font.letterSpacing: Tokens.trackLabel
                    anchors.verticalCenter: parent.verticalCenter
                    Behavior on color { ColorAnimation { duration: Tokens.snap } }
                }
            }
            HoverHandler { id: th; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: tabs.chose(plate.modelData) }
        }
    }
}
