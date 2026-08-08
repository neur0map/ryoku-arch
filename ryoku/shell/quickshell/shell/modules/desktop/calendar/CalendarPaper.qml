import QtQuick
import "../Singletons"

Rectangle {
    id: root

    property bool hovered: false
    property real s: 1

    radius: Theme.radiusWidget * root.s
    color: Theme.surface
    border.width: 1
    border.color: root.hovered ? Theme.lineStrong : Theme.line

    Behavior on border.color { ColorAnimation { duration: Theme.quick } }
}
