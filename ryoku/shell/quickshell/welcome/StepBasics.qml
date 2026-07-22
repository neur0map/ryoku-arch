pragma ComponentBehavior: Bound
import QtQuick
import Ryoku.Ui.Singletons
import "Singletons"

// Step 2 body: the shortcuts that open everything. Each row is the real key combo
// (read straight from the shipped binds) rendered as keycaps, then what it does.
Column {
    id: step
    spacing: 12

    Repeater {
        model: [
            { "combo": "Super + Space",  "desc": "App launcher & command palette" },
            { "combo": "Super + Return", "desc": "A terminal" },
            { "combo": "Super + ,",      "desc": "Ryoku Settings" },
            { "combo": "Super + Tab",    "desc": "Overview \u2014 every workspace at a glance" },
            { "combo": "Super + D",      "desc": "Features sidebar \u2014 stash & tools" },
            { "combo": "Super + Q",      "desc": "Close the focused window" }
        ]

        delegate: Row {
            id: sc
            required property var modelData
            width: step.width
            spacing: 14

            Row {
                id: caps
                width: 168
                spacing: 6
                layoutDirection: Qt.LeftToRight

                Repeater {
                    model: sc.modelData.combo.split(" + ")

                    delegate: Row {
                        id: keyGroup
                        required property string modelData
                        required property int index
                        spacing: 6

                        Text {
                            visible: keyGroup.index > 0
                            anchors.verticalCenter: parent.verticalCenter
                            text: "+"
                            color: Tokens.inkFaint
                            font.family: Tokens.mono
                            font.pixelSize: Tokens.fMicro
                        }

                        KeyCap { text: keyGroup.modelData; big: true }
                    }
                }
            }

            Text {
                anchors.verticalCenter: caps.verticalCenter
                width: sc.width - caps.width - sc.spacing
                wrapMode: Text.WordWrap
                text: sc.modelData.desc
                color: Tokens.inkDim
                font.family: Tokens.ui
                font.pixelSize: Tokens.fBody
            }
        }
    }

    Row {
        width: parent.width
        spacing: 10
        topPadding: 4

        Rectangle {
            width: 16
            height: 1
            color: Tokens.lineStrong
            anchors.verticalCenter: note.verticalCenter
        }

        Text {
            id: note
            width: step.width - 26
            wrapMode: Text.WordWrap
            text: "Press Super + K anytime for the complete shortcut legend."
            color: Tokens.inkFaint
            font.family: Tokens.ui
            font.pixelSize: Tokens.fSmall
        }
    }
}
