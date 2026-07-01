pragma ComponentBehavior: Bound
import QtQuick
import "../Singletons"

// one event line for the calendar faces: start time (or "all"), the note, and a
// delete tick that removes it from the shared Events store. reused by the month,
// week and agenda faces so the row reads identically everywhere.
Row {
    id: root

    property var event: null
    property real s: 1
    property color accent: Theme.ink

    spacing: Math.round(8 * root.s)
    height: Math.round(20 * root.s)

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(3 * root.s)
        height: Math.round(12 * root.s)
        radius: width / 2
        color: root.accent
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(34 * root.s)
        text: root.event && root.event.time && root.event.time.length > 0 ? root.event.time : "all"
        color: Theme.inkDim
        font.family: Theme.font
        font.pixelSize: Math.round(10 * root.s)
        font.features: { "tnum": 1 }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: root.width - Math.round((3 + 34 + 18) * root.s) - root.spacing * 3
        text: root.event ? root.event.text : ""
        elide: Text.ElideRight
        color: Theme.ink
        font.family: Theme.font
        font.pixelSize: Math.round(11 * root.s)
    }

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.round(18 * root.s)
        height: Math.round(18 * root.s)
        radius: Math.round(6 * root.s)
        color: delArea.containsMouse ? Qt.rgba(Theme.ink.r, Theme.ink.g, Theme.ink.b, 0.08) : "transparent"

        Text {
            anchors.centerIn: parent
            text: "\u00d7"
            color: delArea.containsMouse ? Theme.brand : Theme.faint
            font.family: Theme.font
            font.pixelSize: Math.round(13 * root.s)
        }

        MouseArea {
            id: delArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: if (root.event) Events.remove(root.event.id)
        }
    }
}
