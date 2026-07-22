pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui.Singletons
import "Singletons"

// Step 5 body: the send-off. A short recap, a jump into Ryoku Settings, and a
// reminder that the shortcut legend is always a keystroke away. `openSettings()` is
// handled by Welcome.qml (it launches the Hub and closes the tour).
Column {
    id: step
    spacing: 22

    signal openSettings()

    Text {
        width: parent.width
        wrapMode: Text.WordWrap
        text: "That's the tour. The desktop is yours now \u2014 explore, break things, tune them "
            + "back. Nothing here is locked."
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
                "Super + Space launches anything.",
                "Hover a top corner for the sidebars.",
                "Super + , opens Settings for everything else."
            ]

            delegate: Row {
                id: tick
                required property string modelData
                width: step.width
                spacing: 12

                Rectangle { width: 16; height: 1; color: Tokens.lineStrong; anchors.verticalCenter: label.verticalCenter }

                Text {
                    id: label
                    width: tick.width - 28
                    wrapMode: Text.WordWrap
                    text: tick.modelData
                    color: Tokens.inkMuted
                    font.family: Tokens.ui
                    font.pixelSize: Tokens.fBody
                }
            }
        }
    }

    WelcomeButton {
        kind: "outline"
        label: "Open Ryoku Settings"
        onClicked: step.openSettings()
    }
}
