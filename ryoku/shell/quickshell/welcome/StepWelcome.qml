pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Step 1 body: the warm opening. A short editorial paragraph, then three value
// ticks that echo the eyebrow's vermillion mark. The header (eyebrow + title +
// subtitle) is drawn by Welcome.qml; this is only the body.
Column {
    id: step
    spacing: 22

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "You've arrived. Ryoku is a single, hand-built desktop \u2014 one bar, one "
            + "launcher, one control plane \u2014 carved on Arch and Hyprland. This is a "
            + "two-minute tour of where things live and how to make it yours."
        color: Theme.cream
        font.family: Theme.font
        font.pixelSize: 15
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
                    height: 1.5
                    color: Theme.sun
                    anchors.verticalCenter: label.verticalCenter
                }

                Text {
                    id: label
                    width: tick.width - 28
                    wrapMode: Text.WordWrap
                    text: tick.modelData
                    color: Theme.subtle
                    font.family: Theme.font
                    font.pixelSize: 14
                    lineHeight: 1.3
                }
            }
        }
    }
}
