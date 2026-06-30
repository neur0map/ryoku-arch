import QtQuick
import "Singletons"

// One wallhaven thumbnail in the browse grid. Hover lifts the border and shows
// the resolution; the picked one wears an ember frame + corner tick.
Rectangle {
    id: cell

    property var item
    property bool active: false
    signal picked()
    signal opened()

    radius: 10
    color: Theme.surfaceLo
    border.width: cell.active ? 1.6 : 1
    border.color: cell.active ? Theme.ember : (ma.containsMouse ? Qt.alpha(Theme.cream, 0.35) : Theme.line)
    clip: true
    Behavior on border.color { ColorAnimation { duration: Theme.quick } }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        asynchronous: true
        cache: true
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.ceil(cell.width * 1.6), Math.ceil(cell.height * 1.6))
        source: cell.item ? cell.item.thumb : ""
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: ma.containsMouse && !cell.active
        color: Qt.rgba(0, 0, 0, 0.3)
    }

    Text {
        visible: ma.containsMouse
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 6
        text: cell.item ? cell.item.resolution : ""
        color: Theme.bright
        font.family: Theme.mono
        font.pixelSize: 10
        style: Text.Outline
        styleColor: Qt.rgba(0, 0, 0, 0.5)
    }

    // ember corner tick on the active cell.
    Rectangle {
        visible: cell.active
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 16
        height: 16
        radius: 8
        color: Theme.ember
        Icon { anchors.centerIn: parent; name: "check"; size: 11; weight: 2.2; tint: Theme.onAccent }
    }

    MouseArea {
        id: ma
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: (e) => { if (e.button === Qt.RightButton) cell.opened(); else cell.picked(); }
    }
}
