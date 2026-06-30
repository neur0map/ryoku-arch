import QtQuick
import "Singletons"

// Pill switch, ember when on.
Item {
    id: t
    property bool on: false
    signal toggled(bool v)

    implicitWidth: 42
    implicitHeight: 24
    opacity: enabled ? 1 : 0.4

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: t.on ? Theme.frameBg : Theme.surfaceLo
        border.width: 1
        border.color: t.on ? Theme.ember : Theme.line
        Behavior on color { ColorAnimation { duration: Theme.quick } }
        Behavior on border.color { ColorAnimation { duration: Theme.quick } }
    }
    Rectangle {
        width: parent.height - 8
        height: width
        radius: width / 2
        y: 4
        x: t.on ? parent.width - width - 4 : 4
        color: t.on ? Theme.ember : Theme.dim
        Behavior on x { NumberAnimation { duration: Theme.quick; easing.type: Theme.ease } }
        Behavior on color { ColorAnimation { duration: Theme.quick } }
    }

    HoverHandler { enabled: t.enabled; cursorShape: Qt.PointingHandCursor }
    TapHandler { enabled: t.enabled; onTapped: t.toggled(!t.on) }
}
