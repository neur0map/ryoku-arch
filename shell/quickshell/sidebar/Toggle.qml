import QtQuick
import "Singletons"

Rectangle {
    id: control

    property real s: 1
    property bool on: false
    signal toggled()

    width: 38 * s
    height: 22 * s
    radius: height / 2
    border.width: 1
    border.color: on ? Theme.vermLit : Theme.border
    color: on ? "transparent" : Theme.trackBg
    gradient: on ? onGrad : null

    Gradient {
        id: onGrad
        GradientStop { position: 0.0; color: Theme.vermLit }
        GradientStop { position: 1.0; color: Theme.verm }
    }

    Rectangle {
        width: 16 * control.s
        height: 16 * control.s
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: control.on ? parent.width - width - 3 * control.s : 3 * control.s
        color: control.on ? Theme.onAccent : Theme.dim
        Behavior on x { NumberAnimation { duration: 130 } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: control.toggled()
    }
}
