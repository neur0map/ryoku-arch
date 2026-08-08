import QtQuick
import Ryoku.Ui.Singletons

// The palette as one contiguous, hairline-framed swatch strip. The
// swatches carry their own colour: a swatch's job is to be its colour, so this
// is the one place chroma is allowed (amendment 6). Everything around it is ink.
Rectangle {
    id: strip
    property var colors: []
    readonly property int n: 16

    implicitHeight: 22
    color: "transparent"
    radius: Tokens.radius
    border.width: Tokens.border
    border.color: Tokens.line
    clip: true

    Row {
        anchors.fill: parent
        anchors.margins: 1
        Repeater {
            model: strip.n
            delegate: Rectangle {
                required property int index
                width: (strip.width - 2) / strip.n
                height: parent.height
                readonly property bool has: strip.colors && strip.colors.length > index && strip.colors[index]
                color: has ? strip.colors[index] : Tokens.paper
                Behavior on color { ColorAnimation { duration: Tokens.swap } }
                // a hairline seam between empty (loading) cells so the strip still
                // reads as sixteen slots before the palette lands.
                Rectangle {
                    visible: !parent.has && index > 0
                    width: 1; height: parent.height
                    color: Tokens.lineSoft
                }
            }
        }
    }
}
