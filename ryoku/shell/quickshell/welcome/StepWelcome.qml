pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui.Singletons
import "Singletons"

// Step 1 body: the warm opening. A short editorial paragraph, then three value
// ticks -- hairline ink marks, no accent; the sun stays with the mark and the
// art. The header (eyebrow + title + subtitle) is drawn by Welcome.qml; this is
// only the body.
Column {
    id: step
    spacing: 22

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "You've arrived. " + Theme.brandName + " is a single, hand-built desktop \u2014 one bar, one "
            + "launcher, one control plane \u2014 carved on Arch and Hyprland. This is a "
            + "two-minute tour of where things live and how to make it yours."
        color: Tokens.inkDim
        font.family: Tokens.ui
        font.pixelSize: Tokens.fRow
        lineHeight: 1.35
    }

    Column {
        width: parent.width
        spacing: 13

        Repeater {
            model: [
                "One shell, one look \u2014 the bar, panels, and launcher all speak the same language.",
                "Your colours follow your wallpaper, automatically.",
                "Every choice lives in Ryoku Settings, a keystroke away."
            ]

            delegate: Row {
                id: tick
                required property string modelData
                width: step.width
                spacing: 12

                Rectangle {
                    width: 16
                    height: 1
                    color: Tokens.lineStrong
                    anchors.verticalCenter: label.verticalCenter
                }

                Text {
                    id: label
                    width: tick.width - 28
                    wrapMode: Text.WordWrap
                    text: tick.modelData
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody
                    lineHeight: 1.3
                }
            }
        }
    }
}
