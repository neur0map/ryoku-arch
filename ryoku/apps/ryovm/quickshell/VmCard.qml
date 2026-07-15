import QtQuick
import "Singletons"

// One VM in the yard: a hard-shadowed plate carrying the OS badge, the name, a
// compact spec line, and a split-flap state word — the departure-board row for
// this machine. A running machine hoists a vermillion signal rail on its left
// edge; the selected plate wears the ember frame.
Item {
    id: card

    property var item
    property bool active: false
    signal picked()

    readonly property bool running: card.item ? card.item.running === true : false

    height: 68

    // hard offset shadow: depth from geometry, never glow.
    Rectangle {
        x: 4; y: 4
        width: face.width
        height: face.height
        color: Theme.shadow
        antialiasing: false
    }

    Rectangle {
        id: face
        width: parent.width - 4
        height: parent.height - 4
        color: Theme.surfaceLo
        antialiasing: false
        border.width: card.active ? 1.6 : 1
        border.color: card.active ? Theme.ember : (ma.containsMouse ? Qt.alpha(Theme.cream, 0.3) : Theme.line)
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }

        // signal rail: hoisted while the machine runs. Mechanical: it snaps.
        Rectangle {
            id: rail
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.margins: 1
            width: card.running ? 4 : 0
            color: Theme.ember
            antialiasing: false
        }

        // OS badge: a stamped square plate.
        Rectangle {
            id: badge
            anchors.left: parent.left
            anchors.leftMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            width: 40
            height: 40
            gradient: Gradient {
                GradientStop { position: 0.0; color: Theme.keyTop }
                GradientStop { position: 1.0; color: Theme.keyBot }
            }
            border.width: 1
            border.color: card.active ? Qt.alpha(Theme.ember, 0.5) : Theme.line
            antialiasing: false
            OsIcon {
                anchors.centerIn: parent
                width: 26
                height: 26
                size: 26
                slug: card.item ? (card.item.os || "") : ""
                label: card.item ? (card.item.name || card.item.os || "") : ""
                glyphTint: card.active ? Theme.ember : Theme.cream
            }
        }

        Column {
            anchors.left: badge.right
            anchors.leftMargin: 13
            anchors.right: stateFlap.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: card.item ? card.item.name : ""
                color: Theme.bright
                font.family: Theme.font
                font.pixelSize: 14
                font.weight: Font.DemiBold
            }
            Row {
                spacing: 6
                Text {
                    text: card.item ? (card.item.cores + (card.item.cores === "auto" ? " cores" : "c")) : ""
                    color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11
                }
                Text { text: "·"; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 11 }
                Text {
                    text: card.item ? card.item.ram : ""
                    color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11
                }
                Text { text: "·"; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 11 }
                Text {
                    text: card.item ? ({ "gtk": "window", "spice": "SPICE", "none": "headless" })[card.item.display] || card.item.display : ""
                    color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11
                }
                Text { text: "·"; color: Theme.faint; font.family: Theme.mono; font.pixelSize: 11 }
                Text {
                    text: card.item && card.item.diskUsed > 0 ? Vm.human(card.item.diskUsed) : "—"
                    color: Theme.dim; font.family: Theme.mono; font.pixelSize: 11
                }
            }
        }

        // the state on its own split-flap drum, registered like a board column.
        FlapWord {
            id: stateFlap
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            text: card.running ? "RUN" : "OFF"
            pad: 3
            cellW: 13
            cellH: 20
            fontPx: 11
            ink: card.running ? Theme.ok : Theme.dim
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: card.picked()
        }
    }
}
