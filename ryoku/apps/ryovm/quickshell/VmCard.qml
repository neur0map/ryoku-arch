import QtQuick
import "Singletons"

// One VM in the library list: an OS badge, the name, a compact spec line, and a
// live state marker (a breathing ember dot when running). The selected card
// wears an ember frame, matching ryowalls' WallCell.
Rectangle {
    id: card

    property var item
    property bool active: false
    signal picked()

    readonly property bool running: card.item ? card.item.running === true : false

    height: 64
    radius: 12
    color: Theme.surfaceLo
    border.width: card.active ? 1.6 : 1
    border.color: card.active ? Theme.ember : (ma.containsMouse ? Qt.alpha(Theme.cream, 0.3) : Theme.line)
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    // OS badge.
    Rectangle {
        id: badge
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 40
        height: 40
        radius: 10
        gradient: Gradient {
            GradientStop { position: 0.0; color: Theme.keyTop }
            GradientStop { position: 1.0; color: Theme.keyBot }
        }
        border.width: 1
        border.color: card.active ? Qt.alpha(Theme.ember, 0.5) : Theme.line
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
        anchors.right: stateCol.left
        anchors.rightMargin: 10
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
        }
    }

    // state marker on the right: a breathing dot + word when running.
    Row {
        id: stateCol
        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 7
        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 8
            height: 8
            radius: 4
            color: card.running ? Theme.ok : Theme.faint
            SequentialAnimation on opacity {
                running: card.running
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.35; duration: 900; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.35; to: 1; duration: 900; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: card.running ? "Running" : "Stopped"
            color: card.running ? Theme.ok : Theme.faint
            font.family: Theme.mono
            font.pixelSize: 10
            font.weight: Font.DemiBold
            font.letterSpacing: 0.5
        }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: card.picked()
    }
}
