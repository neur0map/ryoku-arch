import QtQuick
import "Singletons"

Rectangle {
    id: tg
    property bool on: false
    signal toggled(bool v)
    implicitWidth: 42
    implicitHeight: 24
    radius: 12
    color: on ? Theme.ember : Theme.field
    border.width: 1
    border.color: on ? Theme.ember : Theme.hair
    Rectangle {
        width: 18; height: 18; radius: 9; y: 3
        x: tg.on ? parent.width - width - 3 : 3
        color: "#ffffff"
        Behavior on x { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: tg.toggled(!tg.on) }
}
