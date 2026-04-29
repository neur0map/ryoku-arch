import QtQuick
import "../"

Rectangle {
    id: root
    width: 20
    height: 20
    radius: 4

    color: hover.hovered ? Theme.active : "transparent"

    property string text: ""
    property color textColor: Theme.text
    signal clicked()

    Text {
        anchors.centerIn: parent
        // Ryoku: shift slightly down so glyph optical-centers inside the
        // button (most Nerd Font glyphs sit slightly above true center).
        anchors.verticalCenterOffset: 1
        text: root.text

        color: hover.hovered ? Theme.background : root.textColor

        font.pixelSize: 10
    }

    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }
}
