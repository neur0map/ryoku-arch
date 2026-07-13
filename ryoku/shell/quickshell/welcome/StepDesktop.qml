pragma ComponentBehavior: Bound
import QtQuick
import "Singletons"

// Step 3 body: where the desktop's surfaces live and how to reach them. Four flat
// brutalist cards (hairline border, hard offset shadow), each naming a surface,
// how to summon it, and what it holds.
Grid {
    id: step
    columns: 2
    columnSpacing: 14
    rowSpacing: 14

    readonly property real cardW: (width - columnSpacing) / 2

    Repeater {
        model: [
            { "name": "The bar",       "reach": "Top edge",      "desc": "The " + Theme.mark + " seal, workspaces, clock, tray and status ride the top edge." },
            { "name": "The launcher",  "reach": "Super + Space", "desc": "Search apps, run commands, or ask a quick question." },
            { "name": "The sidebars",  "reach": "Hover a corner","desc": "Left: your stash & features. Right: system controls, notifications, media." },
            { "name": "Ryoku Settings","reach": "Super + ,",     "desc": "Displays, appearance, keybinds, the shell \u2014 every knob in one place." }
        ]

        delegate: Item {
            id: card
            required property var modelData
            width: step.cardW
            height: 132

            // hard brutalist offset shadow.
            Rectangle {
                x: Theme.shadowStep
                y: Theme.shadowStep
                width: parent.width
                height: parent.height
                color: Theme.shadow
                opacity: 0.5
                antialiasing: false
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.panel
                radius: Theme.radius
                border.width: 1
                border.color: hov.hovered ? Theme.lineStrong : Theme.line
                Behavior on border.color { ColorAnimation { duration: Theme.quick } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    Text {
                        text: card.modelData.name
                        color: Theme.bright
                        font.family: Theme.display
                        font.pixelSize: 19
                        font.weight: Font.DemiBold
                    }

                    Row {
                        spacing: 8
                        Rectangle { width: 14; height: 1.5; color: Theme.sun; anchors.verticalCenter: reach.verticalCenter }
                        Text {
                            id: reach
                            text: card.modelData.reach
                            color: Theme.gold
                            font.family: Theme.mono
                            font.pixelSize: 11
                            font.letterSpacing: 1.6
                            font.capitalization: Font.AllUppercase
                        }
                    }

                    Text {
                        width: parent.width
                        wrapMode: Text.WordWrap
                        text: card.modelData.desc
                        color: Theme.subtle
                        font.family: Theme.font
                        font.pixelSize: 13
                        lineHeight: 1.25
                    }
                }

                HoverHandler { id: hov }
            }
        }
    }
}
