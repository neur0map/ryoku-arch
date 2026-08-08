import QtQuick
import shell.services

Item {
    id: root
    property real scale: 1
    property real thickness: 1
    property real inset: 8 * scale
    implicitHeight: thickness

    Rectangle {
        x: root.inset
        width: Math.max(0, root.width - root.inset * 2)
        height: root.thickness
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.outlineVariant
    }
}
